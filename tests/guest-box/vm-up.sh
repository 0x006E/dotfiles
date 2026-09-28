#!/usr/bin/env bash
# Boot the guest-box test VM and expose it two ways:
#   - a serial console, readable as a log and typeable into
#   - a VNC screen, for looking at and clicking the actual guest desktop
#
# Usage: vm-up.sh [--reset] [--web-port N] [--vnc-port N] [--console-port N]
#
#   --reset   throw the disk away and start from a clean NixOS install. Off by
#             default: the disk carries the guest's box, and re-creating that
#             costs ~15 minutes of pulling and apt. Only reset when testing what
#             a *first* login does.
set -euo pipefail

here="$(cd -- "$(dirname -- "$0")" && pwd)"
# Three separate ports, and they have to stay separate:
#   vnc_port     plain VNC on 5900+N, for a VNC client that speaks TCP
#   ws_port      QEMU's own VNC-over-WebSocket listener. noVNC speaks this
#                directly, so nothing has to proxy TCP to WebSocket -- which is
#                why websockify is not in the picture: it drags in numpy.
#   web_port     a static server for noVNC's own files, and nothing else
#
# web_port and ws_port were the same number at first, and QEMU won the bind, so
# the static server died silently and every vnc.html request 404'd.
vnc_port=59
ws_port=6081
web_port=6080
console_port=6010
reset=0
log=/tmp/guest-box-vm.log
qmp=/tmp/guest-box-qmp.sock

while [ $# -gt 0 ]; do
  case "$1" in
    --reset) reset=1; shift ;;
    --web-port) web_port="$2"; shift 2 ;;
    --ws-port) ws_port="$2"; shift 2 ;;
    --vnc-port) vnc_port="$2"; shift 2 ;;
    --console-port) console_port="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

echo "==> building the test VM"
vm="$(cd "$here" && nix build --print-out-paths .#default)"
runner="$vm/bin/run-nixos-vm"
echo "==> $runner"

# The runner creates ./nixos.qcow2 next to wherever it is started, so it has to
# be started from a writable directory -- not from the read-only store.
run_dir=/tmp/guest-box-vm
mkdir -p "$run_dir"
if [ "$reset" -eq 1 ]; then
  rm -f "$run_dir/nixos.qcow2"
fi

# The runner execs qemu with -nographic, so the guest's serial port is qemu's
# own stdin/stdout; vm-console.py below wraps that in a pty instead of letting
# it land in a file nobody can type into. -vnc rides on the same command line,
# which qemu honours alongside -nographic (both -nographic and -display none
# were verified to work with -vnc).
echo "==> starting qemu (console -> $log, VNC -> 127.0.0.1:$((5900 + vnc_port)), websocket -> $ws_port)"
: >"$log"
rm -f "$qmp"

# The runner creates ./nixos.qcow2 next to wherever it is started, so qemu runs
# from the writable run_dir rather than from the read-only store.
cd "$run_dir"

# vm-console.py puts a pty between the host and qemu's stdio, so the guest's
# serial console is both logged to $log *and* reachable: `vm-console.py console
# --send` types at the guest, which is how a failed session gets looked at.
nohup nix shell nixpkgs#python3 -c \
  python3 "$here/vm-console.py" serve --log "$log" --port "$console_port" -- \
  "$runner" \
  -vnc ":$vnc_port,websocket=$ws_port" \
  -qmp "unix:$qmp,server=on,wait=off" \
  >/tmp/guest-box-vmup-qemu.log 2>&1 &
echo $! >/tmp/guest-box-vm.pid

# noVNC's own files, served from the stdlib so this needs nothing but python.
# Started only if something is not already serving there, and then checked: a
# silent failure here looks exactly like broken noVNC.
if ! curl -fsS -o /dev/null --max-time 3 "http://127.0.0.1:$web_port/vnc.html"; then
  # An earlier run's server still holding the port is the nastier case: it
  # answers 404s that look exactly like a broken noVNC, and this run's server
  # then dies on the bind without a word. Take the port over from whoever has
  # it -- asking ss, because a pgrep pattern broad enough to find these also
  # matches the shell doing the asking.
  for pid in $(ss -ltnp 2>/dev/null |
    grep ":$web_port " |
    sed -n 's/.*pid=\([0-9]*\).*/\1/p'); do
    kill "$pid" 2>/dev/null || true
  done
  rm -f /tmp/guest-box-novnc.pid
  for _ in $(seq 1 25); do
    ss -ltn 2>/dev/null | grep -q ":$web_port " || break
    sleep 0.2
  done
  # share/webapps/novnc, not the output root: the root holds bin/ and share/,
  # and serving it produces a 404 for every file noVNC asks for.
  novnc="$(nix build --no-link --print-out-paths nixpkgs#novnc)/share/webapps/novnc"
  nohup nix shell nixpkgs#python3 -c \
    python3 -m http.server "$web_port" --bind 127.0.0.1 --directory "$novnc" \
    >/tmp/noVNC.log 2>&1 &
  echo $! >/tmp/guest-box-novnc.pid
  for _ in $(seq 1 50); do
    curl -fsS -o /dev/null --max-time 2 "http://127.0.0.1:$web_port/vnc.html" && break
    sleep 0.2
  done
  if curl -fsS -o /dev/null --max-time 3 "http://127.0.0.1:$web_port/vnc.html"; then
    echo "==> serving noVNC from $novnc on $web_port"
  else
    echo "==> could not serve noVNC on $web_port; see /tmp/noVNC.log" >&2
  fi
fi

echo
echo "==> follow the guest with:  tail -f $log"
echo "==> type at the guest with: nix shell nixpkgs#python3 -c python3 $here/vm-console.py console --send 'ls\\n'"
# host/port/path, and the empty path, are all load-bearing: noVNC builds
# "<page host>:<port>/<path>", so pointing it at the websocket port needs host
# and port, and QEMU's VNC websocket answers only on exactly "/" -- websockify's
# conventional /websockify path gets a 404 from it.
echo "==> open the desktop with: http://127.0.0.1:$web_port/vnc.html?autoconnect=1&resize=scale&host=127.0.0.1&port=$ws_port&path="
echo "==> screenshots and keys:  ./vm-shot.sh /tmp/shot.png"
echo "==> stop it with:           kill \$(cat /tmp/guest-box-vm.pid)"
