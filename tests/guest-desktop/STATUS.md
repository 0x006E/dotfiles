# guest-desktop test notes

Scratch notes for verifying `desktop.guest-desktop` in the throwaway VM.
Updated as runs happen; the conclusions at the bottom are what matter.

## Harness

    ./vm-up.sh                 # boot (serial -> /tmp/guest-desktop-vm/console.log)
    ./vm-up.sh --reset         # discard the disk and start clean
    ./vmg logins root root     # root shell on the serial console
    ./vmg send '<command>'     # type at that shell
    ./vmg run <script.sh> 120  # stage a script over virtiofs and run it
    ./vmg log 40               # tail the console
    spicy -h localhost -p 5924 / spicy-screenshot -h localhost -p 5924

Graphics are `virtio-gpu-gl-pci` + `-display egl-headless` + `-spice`. `-vnc`
does not work in that combination ("The console requires a GL context").

Long commands are staged as base64 and decoded in the guest, because the serial
console cannot survive nested quoting:

    B=$(base64 -w0 script.sh)
    ./vmg send "echo '$B' | base64 -d > /tmp/out.sh; sh /tmp/out.sh"

Use a fresh inner filename each run: a file chowned to `guest` on an earlier run
cannot be overwritten by the next one ("Permission denied").

## What is proven

Rootless podman works for `guest` (`podman pull` succeeds; `distrobox create`
succeeds). No "cannot chdir to /root" -- that was an artifact of an older image.

Container creation (current, verified form):

    distrobox create --name gnome --init \
      --additional-packages "systemd dbus dbus-daemon" \
      --image registry.fedoraproject.org/fedora:44 \
      --additional-flags "--device /dev/dri --device /dev/input -v /run/dbus/system_bus_socket:/run/dbus/system_bus_socket"

Things that cost time and are easy to get wrong:

- **Pre-pull the image.** `distrobox create` prompts `Image ... not found. Do you
  want to pull the image now? [Y/n]`, and with no tty on stdin the `read` fails
  with "Bad file descriptor". Run `podman pull <image>` first.
- **`-v` to `distrobox create` is `--verbose`, not `--volume`.**
  `distrobox create -v /dev/dri:/dev/dri` silently consumed the path as the
  *container name* and podman rejected it with
  `names must match [a-zA-Z0-9][a-zA-Z0-9_.-]*: invalid argument`.
- **There is no `distrobox create --device`.** It fails with "Invalid flag
  '--device'". `--additional-flags` is the only way in; verify with
  `podman inspect <name> --format '{{json .HostConfig.Devices}}'`, which must not
  be `[]`. Note distrobox *also* bind-mounts /dev/dri implicitly, so the nodes
  being visible proves nothing on its own.
- **`-r`/`-w` inside the container proves nothing.** The container user is
  root-mapped, so `-w` is always true. Only `open(O_RDWR)` is evidence.

Inside the container:

- `PID1=systemd` -- systemd really is init.
- `systemctl is-system-running` = `running`, despite podman warning
  `The cgroupv2 manager is set to systemd but there is no systemd user session
  available` / `Falling back to --cgroup-manager=cgroupfs`. The fallback does not
  stop systemd here. `loginctl enable-linger guest` silences the warning.
- `loginctl list-seats` shows `seat0`; `/dev/tty0` and `/dev/input/event0` are
  visible.

## Resolved: the seat, not the device

The `/dev/dri/card0` scare was a misdiagnosis. `nobody:nobody 0660` looks like a
wall, but a real `open(O_RDWR)` succeeds — the runtime sets the device up with
permissions the container user has. Do not "fix" it with an ACL (udev has no ACL
key; `ACLS=` fails the build) or with `MODE="0666"`.

The real blocker was one layer up, and it is resolved. Mutter's native backend
takes display devices through logind (`meta-launcher.c`, `TakeDevice` on the
session's seat), finding the session via `XDG_SESSION_ID`, then its PID, then the
display — dying with "Failed to find any matching session" when none resolve.
The box's own logind can never satisfy this: its sessions are all
`type=unspecified`, and its `seat0` has `Devices: n/a`, because distrobox masks
`systemd-udevd` and no second udevd can bind the control socket ("Address already
in use"), so no `ID_SEAT` tags ever exist in the box. Unmasking cannot work;
do not try again.

The fix is the host system-bus mount (`-v
/run/dbus/system_bus_socket:/run/dbus/system_bus_socket`, the doc's own flag):
with it the box sees the user's real host session, mutter starts with zero
errors and serves a live `wayland-0` socket. Verified on this machine's real
Intel iGPU against mutter 50.5. This is the one deliberate hole in the container
boundary; D-Bus policy still applies and the box presents as the unprivileged
guest uid.

Related: do NOT wrap the session in `dbus-run-session`. The container runs its
own systemd `--user`, so the user bus exists, and `dbus-run-session` replaces it
with a private one — which broke gnome-session with "Failed to upload
environment to systemd". Plain `distrobox enter` is correct. The
`set_gnome_env` assertion that motivated the wrapper only fires with no bus at
all (bare `podman run` without `XDG_RUNTIME_DIR`), never under enter.

Fedora 44 ships GNOME Shell / mutter **50.5**. Mutter dropped its X11 backend in
the 50 cycle and has no `--nested` either (`--display-server` is documented as
"rather than nested", and the flag it would invert no longer exists) — so the
native-compositor path above is the only one, and it works.

## Still open

- `gnome-session` end to end in the box (compositor runs; the full session with
  `org.gnome.Shell@user` still needs the host-bus mount in place, untested
  together).
- The `AssertEnvironment=XDG_SESSION_TYPE=wayland` on `org.gnome.Shell@.service`
  is checked against the *user manager's* environment: `systemctl --user
  set-environment` is needed if the manager does not already carry it.
- Whether mutter can claim a VT and mode-set the real panel vs headless.
- Greeter handoff on the real machine; `nithin` regression check after.
## Test-VM staleness gotcha

`run-nixos-vm` boots the kernel/initrd from the current build but stage-2
switches into the system *installed on the qcow2*. Rebuilding the flake does
not update a booted disk: new `vm.nix` options (e.g. `services.qemuGuest`)
only take effect after `./vm-up.sh --reset`. Symptom of a stale disk is
commands failing for things the current `vm.nix` definitely enables.

## vm-qga.mjs: guest-exec without the serial console

`./vm-qga.mjs [--as USER] [--timeout SECS] [--input-file F] [--transcript P]
<command> [args...]` runs a command in the guest via the QEMU guest agent and
streams stdout/stderr back with the real exit code. `--transcript PATH`
appends a timestamped record for following along with `tail -f`.

Three things learned building it:

- The agent socket is spoken to **directly** (`/tmp/guest-desktop-vm/qga.sock`),
  not through QMP. The qemu build `run-nixos-vm` uses (qemu-host-cpu-only)
  has no `guest-*` QMP proxy commands compiled in at all — verified via
  `query-commands` (241 commands, zero `guest-*`). The agent protocol is the
  same JSON framing without the greeting/capabilities handshake; `guest-sync`
  is the connectivity check.
- `guest-exec` needs **absolute paths** (`/bin/sh`, not `sh`): the agent does
  no PATH lookup ("Failed to execute child process").
- Never put `#` comments inside a `\`-continued shell command (vm-up.sh once
  had them): the comment ends the continuation and silently drops the rest,
  which is how vm-console.py received an empty argv and died with IndexError.
