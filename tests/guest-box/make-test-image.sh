#!/usr/bin/env bash
# Build the test image on the host, hand it to the VM, and load it into the
# guest's rootless podman store.
#
# Why the host and not the VM: the box's desktop is ~300 MB of MATE plus a
# Chrome .deb, and installing that inside the VM on every test run costs about
# ten minutes. The image removes that from the loop -- but the image has to end
# up in the *guest's* rootless podman store, because that is the store the box
# is created from, and a rootful image is invisible to it.
#
# So: build where there is a real user session (the host), `podman load` inside
# the VM, which is pure storage and needs neither a session nor a container
# runtime. Building *in* the VM does not work: `podman build` runs each step
# through buildah, which wants the systemd user session that a guest cannot
# have -- their login shell is the box itself.
#
# The Containerfile is generated from the production configuration, so the test
# image cannot drift from what production installs. The only difference in the
# module is services.guest-box.image; the launcher notices the image changed and
# rebuilds the box over, logging it.
#
# Usage:
#   ./make-test-image.sh            # build, transfer, load
#   ./make-test-image.sh --load-only   # the tarball is already in /tmp
#   ./make-test-image.sh --force       # rebuild even if the tarball exists
set -euo pipefail

here="$(cd -- "$(dirname -- "$0")" && pwd)"
image=localhost/guest-box-test:24.04
run="gb$$"
tarball=/tmp/guest-box-test-image.tar
serve_port=8099
console=(nix shell nixpkgs#python3 -c python3 "$here/vm-console.py" console)
log=/tmp/guest-box-vm.log

load_only=0
force=0
for arg in "$@"; do
  case "$arg" in
    --load-only) load_only=1 ;;
    --force) force=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# Commands are submitted, not just typed. The console is a real terminal with a
# line editor, so a send has to *terminate* the line: without the trailing
# newline the command sits in the buffer and the next send appends to it, which
# is how "loginctl enable-linger guest" and a file transfer once ended up as one
# nonsense line. The leading newline clears whatever was left in the buffer.
send() { "${console[@]}" --send $'\n'"$1"$'\n' >/dev/null 2>&1; }
ask() { "${console[@]}" --send $'\n'"$1"$'\n' >/dev/null; }

if ! "${console[@]}" --send $'\n' >/dev/null 2>&1; then
  echo "cannot reach the VM's serial console -- is it running? (./vm-up.sh)" >&2
  exit 1
fi

if [ "$load_only" -eq 0 ] && { [ "$force" -eq 1 ] || [ ! -f "$tarball" ]; }; then
  echo "==> generating the Containerfile from the production configuration"
  # From *production*, not from the test VM: the test VM overrides
  # services.guest-box.image to point at the image being built here, so asking
  # it would produce a Containerfile that FROMs itself.
  repo="$(cd "$here/../.." && pwd)"
  prod="path:$repo#nixosConfigurations.ntsv"
  base=$(cd "$here" && nix eval --raw "$prod.config.services.guest-box.image")
  packages=$(cd "$here" && nix eval --raw "$prod.config.services.guest-box.packages" \
    --apply 'ps: builtins.concatStringsSep " " ps')
  sed -e "s|@BASE@|$base|" -e "s|@PACKAGES@|$packages|" \
    "$here/Containerfile" >/tmp/Containerfile.guest-box
  echo "    base:     $base"
  echo "    packages: $packages"

  engine=docker
  command -v docker >/dev/null 2>&1 || engine=podman
  echo "==> building $image with $engine (~10 minutes)"
  if [ "$engine" = docker ]; then
    docker build -t "$image" -f /tmp/Containerfile.guest-box /tmp
  else
    nix shell nixpkgs#podman -c \
      podman build -t "$image" -f /tmp/Containerfile.guest-box /tmp
  fi

  echo "==> saving to $tarball"
  if [ "$engine" = docker ]; then
    docker save "$image" >"$tarball"
  else
    nix shell nixpkgs#podman -c podman save --format docker-archive "$image" >"$tarball"
  fi
  chmod 0644 "$tarball"
  echo "    $(du -h "$tarball" | cut -f1)"
fi

if [ ! -f "$tarball" ]; then
  echo "no tarball at $tarball" >&2
  exit 1
fi

# The VM reaches the host at 10.0.2.2: that is qemu's user-mode gateway, and it
# maps to the host's loopback -- so a server bound to 127.0.0.1 here is reachable
# from inside, without opening anything to the network.
echo "==> serving $tarball to the VM on 127.0.0.1:$serve_port"
for pid in $(ss -ltnp 2>/dev/null |
  grep ":$serve_port " |
  sed -n 's/.*pid=\([0-9]*\).*/\1/p'); do
  kill "$pid" 2>/dev/null || true
done
# Not `python3` bare: it is not on this host's PATH.
nohup nix shell nixpkgs#python3 -c \
  python3 -m http.server "$serve_port" --bind 127.0.0.1 --directory /tmp \
  >/tmp/guest-box-image-serve.log 2>&1 &
echo $! >/tmp/guest-box-image-serve.pid
for _ in $(seq 1 40); do
  sleep 0.5
  curl -fsSI --max-time 3 "http://127.0.0.1:$serve_port/$(basename "$tarball")" >/dev/null 2>&1 && break
done
curl -fsSI --max-time 5 "http://127.0.0.1:$serve_port/$(basename "$tarball")" >/dev/null || {
  echo "the tarball is not being served; see /tmp/guest-box-image-serve.log" >&2
  exit 1
}

# podman needs /run/user/<uid>, and a guest who has not logged in yet has no
# runtime dir -- logind creates it at first login. Lingering creates it now.
send 'loginctl enable-linger guest'

# The run's token is set *in the VM* and referenced as $GB afterwards. It cannot
# be pasted into the commands, because the shell echoes every command back: a
# pasted token would make the wait finish on the echo of the command that is
# about to print the result, which is how a successful 1.6 GB transfer got
# reported as a failure three times.
send "GB=$run"

echo "==> fetching it in the VM (nix shell has to fetch curl first, then 1.6 GB)"
send "rm -f /tmp/guest-box-image.tar /tmp/image-load.log"
# nix shell for curl: the VM's own package set is bash and vim. nix-command is
# off in the VM (qemu-vm.nix sets features = "" for the image it writes), so say
# so rather than trusting the guest's /etc/nix/nix.conf.
send "cd /tmp; nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#curl -c curl -fsS -o /tmp/guest-box-image.tar http://10.0.2.2:$serve_port/$(basename "$tarball") >/tmp/image-load.log 2>&1; echo RESULT-\$GB fetch=\$? >>/tmp/image-load.log"

echo "==> waiting for the fetch, then loading it as the guest"
for _ in $(seq 1 240); do
  sleep 5
  grep -q "RESULT-$run fetch=" "$log" && break
done
if ! grep -q "RESULT-$run fetch=0" "$log"; then
  echo "the VM could not fetch the tarball:" >&2
  ask 'tail -3 /tmp/image-load.log'
  sleep 1
  tail -c 1500 "$log" | tr -d '\000' | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | tail -5 >&2
  exit 1
fi

# The load itself is storage only, so unlike a build it works from a plain su
# shell. cd /tmp first: this console is root's shell in /root, and su hands that
# cwd to the guest, who cannot enter it.
send "cd /tmp; su -s \$(readlink -f /run/current-system/sw/bin/bash) guest -c 'cd /tmp && XDG_RUNTIME_DIR=/run/user/1000 podman load -i /tmp/guest-box-image.tar' >/tmp/image-load.log 2>&1; echo RESULT-\$GB load=\$? >>/tmp/image-load.log"

for _ in $(seq 1 240); do
  sleep 5
  grep -q "RESULT-$run load=" "$log" && break
done

echo
ask 'clear; su -s $(readlink -f /run/current-system/sw/bin/bash) guest -c "XDG_RUNTIME_DIR=/run/user/1000 podman images" 2>/dev/null | grep guest-box'
sleep 2
tail -c 2000 "$log" | tr -d '\000' | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | tail -8

for pid in $(ss -ltnp 2>/dev/null |
  grep ":$serve_port " |
  sed -n 's/.*pid=\([0-9]*\).*/\1/p'); do
  kill "$pid" 2>/dev/null || true
done
echo
echo "==> now log in as guest on tty1: the box is created from the local image in seconds."
