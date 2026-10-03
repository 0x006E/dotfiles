#!/usr/bin/env bash
# Fast host-side checks for the guest's container, without booting the VM.
#
# Why this exists: the VM's GPU is virgl -- software GL 4.2 -- which makes it
# useless for judging anything to do with real GPU access. The host has the real
# Intel iGPU, so a two-minute test here answers questions a ten-minute VM boot
# cannot. It caught two wrong conclusions the VM had produced:
#
#   * "rootless podman --device cannot reach card0". False. The VM showed card0
#     as nobody:nobody 0660, which looked like a hard blocker. On the host
#     open(O_RDWR) on card1 succeeds. The VM's plain --volume bind mount was the
#     problem, not rootless podman.
#   * "-r/-w inside the container proves access". False, and it is the error that
#     produced the first wrong conclusion: in a rootless container the container
#     user IS root-mapped, so -w is always true. Only open(O_RDWR) means
#     anything.
#
# The VM is still needed for one thing: whether the real greeter hands off to
# this session correctly. See vm-up.sh.
#
# Usage:
#   ./host-probe.sh gpu     device access + mutter as a Wayland display server
#   ./host-probe.sh clean   remove the throwaway container and image
#   ./host-probe.sh all     gpu, then clean
set -euo pipefail

image="docker.io/library/fedora:44"
box=dbx-probe

# Rootless podman needs a policy.json or it refuses to do anything at all, and
# the error ("no policy.json file found") looks nothing like a missing device
# permission.
if [ ! -f "$HOME/.config/containers/policy.json" ]; then
  mkdir -p "$HOME/.config/containers"
  cat >"$HOME/.config/containers/policy.json" <<'JSON'
{
  "default": [{ "type": "insecureAcceptAnything" }],
  "transports": {
    "docker-daemon": { "/run/docker.sock": [{ "type": "insecureAcceptAnything" }] }
  }
}
JSON
  echo "==> wrote ~/.config/containers/policy.json (podman requires one)"
fi

do_gpu() {
  echo "==> host /dev/dri:"
  ls -l /dev/dri/ | sed 's/^/    /'

  echo
  echo "==> creating the probe container"
  # There is no distrobox --device flag: `distrobox create --device /dev/dri`
  # fails with "Invalid flag '--device'". --additional-flags is the only way in,
  # and it does reach the runtime -- verified by inspect below.
  #
  # Inspecting .HostConfig.Devices is the check that matters, because distrobox
  # *also* bind-mounts /dev/dri implicitly. The nodes being visible in the
  # container therefore proves nothing on its own; that is what made an earlier
  # version of this script confidently wrong.
  export DBX_NON_INTERACTIVE=1
  distrobox rm -f "$box" --force >/dev/null 2>&1 || :
  distrobox create --name "$box" --image "$image" \
    --additional-flags "--device /dev/dri --device /dev/input" >/dev/null
  echo "    HostConfig.Devices: $(docker inspect "$box" --format '{{json .HostConfig.Devices}}' 2>/dev/null)"

  echo
  echo "==> inside the container: device access, then mutter as a display server"
  local inner=/tmp/guest-desktop-probe-inner.sh
  cat >"$inner" <<'INNER'
#!/bin/sh
echo "    inside as $(id -un), groups: $(id -nG)"

# open(O_RDWR), not test -w: in a rootless container the user is root-mapped so
# -w is always true and proves nothing.
python3 -c '
import os
for f in ["/dev/dri/card1", "/dev/dri/renderD128"]:
    try:
        os.close(os.open(f, os.O_RDWR))
        print("    OPEN OK  :", f)
    except Exception as e:
        print("    OPEN FAIL:", f, e)
'

echo "    installing mutter (the slow part, a few minutes)"
su -c 'dnf -q install -y mutter dbus dbus-daemon' >/tmp/probe-install.log 2>&1 || {
  echo "    INSTALL FAILED:"; tail -5 /tmp/probe-install.log; exit 1;
}
rpm -q mutter | sed 's/^/    /'

# mutter aborts on `set_gnome_env: assertion failed: (session_bus)` without one.
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
mkdir -p "$XDG_RUNTIME_DIR"
# Resolve via PATH, never `find /`: this host has chroots under ~/projects whose
# binaries are foreign-arch and yield a confusing "Exec format error".
DBS="$(command -v dbus-run-session || echo /usr/bin/dbus-run-session)"

# --headless --virtual-monitor rather than a real mode setting: it needs no VT
# and no console, which is what makes it testable from a script at all.
"$DBS" -- sh -c '
  mutter --headless --virtual-monitor 1280x800 --no-x11 >/tmp/m.log 2>&1 &
  sleep 10
  echo "    wayland socket: $(test -S "$XDG_RUNTIME_DIR/wayland-0" && echo present || echo MISSING)"
  echo "    --- mutter ---"
  grep -E "display server|Added device|selected as primary|EGL context|Wayland display name|ERROR" /tmp/m.log | sed "s/^/    /"
  kill %1 2>/dev/null || true
'
INNER
  chmod +x "$inner"
  distrobox enter "$box" -- sh "$inner"
  rm -f "$inner"
}

do_clean() {
  echo "==> removing $box and the image"
  distrobox rm -f "$box" --force >/dev/null 2>&1 || :
  docker rmi -f "$image" >/dev/null 2>&1 || :
  echo "==> done; remaining containers:"
  docker ps -a --format '    {{.Names}}' 2>/dev/null | head -5 || true
}

case "${1:-gpu}" in
  gpu) do_gpu ;;
  clean) do_clean ;;
  all)
    do_gpu
    do_clean
    ;;
  *)
    echo "usage: $0 {gpu|clean|all}" >&2
    exit 2
    ;;
esac