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

## SUPERSEDED: the cgroup-migration detour (kept as a warning)

An earlier version of this section concluded the compositor must live in the
host session scope, proven by migrating PIDs into it via `cgroup.procs` (and
two rendered screenshots). That mechanism is real, but it is NOT required.
What actually fixed it, with zero migration and zero privilege, is below. The
migration evidence stays valid for components that resolve their session *by
PID*; only the "must" was wrong.

## Resolved: XDG_SESSION_ID + two mounts, no migration

The compositor does not need to sit in the host session scope. mutter's first
lookup reads `XDG_SESSION_ID` and validates it with `sd_session_is_active`,
which reads `/run/systemd/sessions/<id>` directly (`sd-login.c:
file_of_session`; missing file = the `ENXIO` "No such device or address" that
appeared in every early failure). The box keeps no such files, so the fix is
a read-only bind of the host directory plus the bus mount, with the session
ID exported into the compositor's environment:

    -v /run/dbus/system_bus_socket:/run/dbus/system_bus_socket
    -v /run/systemd/sessions:/run/systemd/sessions:ro

With both in place, plain `distrobox enter` (no STOP/CONT dance, no cgroup
writes, guest-uid throughout) starts a rendering compositor: session found,
`TakeControl` granted, monitor configured, fourth screenshot. The earlier
"Failed to get status of XDG_SESSION_ID" failures were all missing-file or
missing-variable cases, never a scope problem.

Follow-on, same session: the full `gnome-session` also completes once a
three-line drop-in pulls `graphical-session.target`
(`~/.config/systemd/user/gnome-session@gnome.target.d/pull-graphical.conf`
with `Wants=`+`After=` — `RefuseManualStart` blocks a direct start, and
nothing in any unit file pulls it otherwise; without it gnome-session starts
its target, finds `graphical-session-pre.target` inactive, and quits).
27 GNOME units running (settings daemon, keyring, portals), fifth screenshot.
Root causes along the way, all confirmed: box user manager idling out (pin
with `touch /var/lib/systemd/linger/guest` as box-root, since polkit denies
both uids the `loginctl` form), and a root-owned `/run/user/1000/dconf/user`
from early root-run days breaking gsettings session-name resolution (delete
it once).

Why the confusion lasted so long: most probe runs never had `XDG_SESSION_ID`
in the compositor's environment at all (distrobox-enter's denylist was
suspected; the actual cause was quoting dropping the export through five
shell layers, plus dead session IDs reused across runs). The PID fallback
then ran and failed for the real reason (box PIDs in no host scope), which
made scope look load-bearing.

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

## PROVEN: full GNOME session in the box, with screenshots

`gnome-shell --mode=user` runs as a Wayland display server in the rootless
box, takes the display through logind, and renders. Two SPICE captures show
the Fedora welcome tour and then the Activities overview (wallpaper, search,
clock, dash). The exact recipe that works:

1. Box created WITH `-v /run/dbus/system_bus_socket:/run/dbus/system_bus_socket`
   (else the box's logind knows no seat and mutter dies with "Failed to find
   any matching session" — from `meta-launcher.c:394`, after three fallbacks:
   XDG_SESSION_ID, PID, display).
2. Box's user manager carries the session env (`systemctl --user
   set-environment XDG_SESSION_TYPE=wayland ...`), or the
   `AssertEnvironment=` on `org.gnome.Shell@.service` refuses.
3. The compositor process runs as the box guest (== session owner uid), or
   `TakeControl` denies with "Only owner of session may take control"
   (`logind-session-dbus.c:402`; mutter passes force=false, so owner-uid is
   enough — but `podman exec` defaults to container-root, which maps to a
   subordinate uid, hence denied).
4. The compositor process lives in the host logind session scope (see below).
5. No `dbus-run-session` anywhere (it shadows the working user bus).

Still open: `gnome-session` itself (only `gnome-shell --mode=user` proven;
same env, should follow), VT/modeset on real hardware, greeter handoff,
`nithin` regression check.

## The cgroup problem (and why podman exec is not enough)

`podman exec` moves processes OUT of the caller's cgroup into a libpod scope
(box procs show `.../libpod-<id>.scope/container/init.scope`). Host logind
attributes sessions by cgroup path, so a compositor there is invisible:
`GetSessionByPID` → "does not belong to any known session". Verified:
migrating the PID into the session scope via `cgroup.procs` makes logind
attribute it (`GetSessionByPID` → the session), and everything downstream
works. Deterministic form: payload starts STOPPED (`sh -c 'kill -STOP $$;
exec ...'`), migrate, `kill -CONT` — no race with mutter's ~1s startup lookup.

**Who can migrate is THE open design question.** Root can. The guest cannot:
writing the session scope's `cgroup.procs` (or `mkdir` under it) as the
session owner is denied — delegation covers the user slice, not logind's
session scopes. So the real machine needs a privileged migrator (setuid
helper or sudoers entry, migrating only own-uid PIDs into the caller's own
session). See the plan note below; not yet implemented.

Related traps, all verified:
- `CreateSession` moves ONLY the given PID, not its existing children. Target
  the worker's own PID (recorded via `$$` before it forks anything), never a
  wrapper's (runuser forks first; its children stay behind in the old scope).
- Stale sessions hold VTs: `CreateSession` fails with "Virtual terminal
  already occupied" until old ones are terminated. Stale controllers fail
  `TakeControl` with EBUSY.
- `loginctl terminate-session` on an empty-scope session removes it; cgroup
  paths in scripts must be re-resolved (box init PID changes across restarts;
  hardcoded PIDs go stale).
- Too many backgrounded sleeps exhaust the VM's FD table ("Too many open
  files in system", even `grep` fails to spawn). Reboot to clear; disk
  persists.

## The nsenter dead end (do not retry without new information)

`nsenter -U -m` (keep host cgroups, take box rootfs) fails differently at
every layer, investigated to strace level:
- Net and IPC namespaces are HOST-SHARED in distrobox boxes (same inodes as
  host init) — joining them EPERMs; correctly skipped, nothing lost.
- UTS joins fine; PID was never cleanly isolated.
- GUdev DRM enumeration (`match name=card* + tag=seat`) returns EMPTY via
  nsenter but matches via `podman exec`, with byte-identical files, libs,
  and db content (same dev:ino), in side-by-side A/B/C runs. `udevadm
  export-db` shows 431 devices via enter, 0 via nsenter.
- strace shows libudev opening `/proc/self/fd` mid-resolution and failing
  (the box has its own pidns, entered only with `-p`).
- `-p` fixes `/proc/self` but gives the child a box-local PID, breaking
  host-logind PID identity — mutually exclusive with the session lookup.
- Remounting proc in a private clone is denied (container-root lacks the
  mount cap under podman's seccomp/cap set).
Net: nsenter keeps cgroups but breaks device enumeration; podman exec keeps
enumeration but breaks cgroups. The migrate approach (exec + cgroup fix) is
the one that reaches a desktop. The GUdev-nsenter discrepancy itself is
unexplained; it no longer matters.

## Verdicts on proposed alternatives (all tested or sourced)

- **`podman run/create --cgroups=disabled`**: DEAD. Plain commands work, but
  systemd-as-init exits 255 instantly and silently in every variant (with and
  without `--systemd=always`). The box needs its init and user manager, so
  cgroups stay managed (and the libpod scope with them).
- **`nsenter -r -w`**: wrong model. strace proves libudev fails opening
  `/proc/self/fd` mid-resolution (no `-p`), which root/cwd flags cannot
  affect. Files were already proven identical across views.
- **"Start the box from the session so children inherit"**: wrong about
  podman. crun ALWAYS assigns libpod scopes regardless of creator scope
  (proven: creator in agent-service scope, box in libpod scope). Only
  `--cgroups=disabled` would inherit, which is dead per above.
- **PAMName= system unit**: moves privilege without removing it, and adds
  session-lifecycle problems (service outlives logout, holds DRM into the
  next login). Worse than the migrator.
- **Migrating box init**: pointless alone — exec children fork from conmon
  (libpod scope), not from init. Migrating CONMON would cover all future
  execs, but conmon dying on logout orphans box management; next login must
  `podman start` fresh (which then lands correctly). Considered, not tested.

## VM operation notes

- `loginctl enable-linger guest` is required before `distrobox create --init`,
  or podman falls back to cgroupfs and the box's systemd fails ("Container
  Setup Failure!").
- Unmasking `systemd-udevd` in the box is impossible (host owns the control
  socket: "Address already in use") and unnecessary — leave it masked. But
  its mask breaks `dnf group install gnome-desktop` at the last transaction
  step; unmask (box-root), re-run to complete, done. Harmless to leave
  unmasked.
- Manual `setfacl u:guest:rw /dev/dri/card0` stands in for logind-uaccess (no
  real seat session exists in the VM). It gets wiped by udev re-triggers
  (observed twice); re-apply right before use. On the real machine logind
  maintains it. `chmod 0666` was used once diagnostically; not a proposal.
- `podman exec -d --user guest` for payloads (default exec user is
  container-root, which fails the TakeControl owner check).
- Guest-exec needs absolute paths for EVERYTHING (`/bin/sh` does not exist
  on NixOS; the agent does no PATH lookup).
- `vm-qga.mjs --input-file` feeds stdin (used for python probes and file
  staging into the box).
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
