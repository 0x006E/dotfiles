#!/usr/bin/env bash
# Boot the guest-desktop test VM and expose it two ways:
#   - a serial console, readable as a log and typeable into (vm-console.py)
#   - the guest's actual screen, over SPICE, for looking at the desktop
#
# Usage: vm-up.sh [--reset] [--console-port N] [--spice-port N]
#
#   --reset      throw the disk away and start from a clean NixOS install. Off
#                by default: the disk carries the guest's container, and
#                re-creating that costs ~15 minutes of pulling a Fedora image
#                and installing GNOME. Only reset when testing what a *first*
#                login does.
#   --console-port  port for the serial console bridge (default 6010)
#   --spice-port    port for the SPICE server (default 5924)
#
# Why SPICE and not VNC, which is the obvious choice: the guest's display is
# virtio-gpu with virgl, which means the framebuffer lives in a GL texture on
# the host GPU. Exporting that needs a GL-capable SPICE server, and QEMU
# refuses `-vnc` in that configuration ("The console requires a GL context").
# `-display egl-headless` plus `-spice` is the combination that works, and
# `spicy`/`spicy-screenshot` (spice-gtk) are the clients for it.
#
# rendernode is pinned to the Intel node rather than left to QEMU's probing:
# left alone, egl-headless walks /dev/dri/renderD* in order, and on this
# machine that walk can die on the NVIDIA node with "eglInitialize failed:
# EGL_NOT_INITIALIZED" / "render node init failed" -- even though nothing
# about the NVIDIA GPU changed and plain host EGL still initializes. Pinning
# also makes the choice deterministic instead of enumeration-order luck.
set -euo pipefail

here="$(cd -- "$(dirname -- "$0")" && pwd)"
console_port=6010
spice_port=5924
reset=0
run_dir=/tmp/guest-desktop-vm
log="$run_dir/console.log"
qmp=/tmp/guest-desktop-qmp.sock

while [ $# -gt 0 ]; do
  case "$1" in
    --reset) reset=1; shift ;;
    --console-port) console_port="$2"; shift 2 ;;
    --spice-port) spice_port="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

echo "==> building the test VM"
vm="$(cd "$here" && nix build --print-out-paths .#default)"
runner="$vm/bin/run-nixos-vm"
echo "==> $runner"

# The runner creates ./nixos.qcow2 next to wherever it is started, so qemu has
# to run from a writable directory -- not from the read-only store.
mkdir -p "$run_dir"
if [ "$reset" -eq 1 ]; then
  echo "==> --reset: discarding $run_dir/nixos.qcow2"
  rm -f "$run_dir/nixos.qcow2"
fi

# A stale socket from a killed qemu makes the new one refuse to bind.
rm -f "$qmp" "$run_dir/qga.sock"

# -vga none is not optional. QEMU otherwise adds a std VGA (bochs-drm) device,
# which shows up as a second /dev/dri/cardN in the guest; the VM then has two DRM
# devices and the container's compositor has no way to know which is the screen.
echo "==> starting qemu (serial -> $log, spice -> 127.0.0.1:$spice_port)"
: >"$log"
cd "$run_dir"

# vm-console.py puts a pty between the host and qemu's stdio, so the guest's
# serial console is both logged *and* reachable:
#   vm-console.py --port $console_port --send 'text\n'   types at the guest
#   vm-console.py --port $console_port --watch           follows the console
# vmg (in this directory) wraps that in the higher-level helpers.
#
# The -chardev/-device virtserialport lines are the guest-agent channel. vm.nix
# runs services.qemuGuest, which starts qemu-ga when udev sees the
# org.qemu.guest_agent.0 virtio port. vm-qga.mjs talks to it over QMP
# (guest-exec): real command execution with stdout/stderr/exit codes, no
# serial corruption, no virtiofs staging.
#
# NOTE: no # comments inside the continued command below. A comment line ends
# the continuation, silently dropping the rest of the command -- which is how
# vm-console.py once received an empty argv and died with IndexError.
nohup nix shell nixpkgs#python3 -c \
  python3 "$here/vm-console.py" serve --log "$log" --port "$console_port" -- \
  "$runner" \
  -vga none \
  -device virtio-gpu-gl-pci \
  -display egl-headless,rendernode=/dev/dri/renderD128 \
  -chardev "socket,path=$run_dir/qga.sock,server=on,wait=off,id=qga0" \
  -device virtio-serial-pci \
  -device "virtserialport,chardev=qga0,name=org.qemu.guest_agent.0" \
  -spice "port=$spice_port,disable-ticketing=on" \
  -qmp "unix:$qmp,server=on,wait=off" \
  >"$run_dir/qemu.log" 2>&1 &
echo $! >"$run_dir/qemu.pid"

echo "==> waiting for the guest to reach a login prompt"
for _ in $(seq 1 60); do
  sleep 5
  if tail -c 200 "$log" 2>/dev/null | grep -qa "login:"; then
    echo "==> up. log: $log"
    echo "    screen: spicy -h localhost -p $spice_port"
    echo "    shot:   spicy-screenshot -h localhost -p $spice_port"
    exit 0
  fi
done

echo "==> no login prompt after 5 minutes; tail of the console:" >&2
tail -20 "$log" >&2
exit 1