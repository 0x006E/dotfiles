# The guest desktop

`nithin` gets niri on the host. `guest` gets a full GNOME desktop that is not
installed on this machine at all: it lives in a rootless distrobox container,
created once by hand and then entered by a single greeter session.

The module is `modules/desktop/guest-desktop`, toggled in the host manifest with
`desktop.guest-desktop.enable`. Turn that off and there is no `guest` session,
no podman, no container entry; the account in `modules/config/user.nix` stays.

## One-time setup, as `guest`

The box is built from `containers/gnome/Containerfile` and created with
`containers/gnome/build.sh`. Run this once, from a login on the `guest`
account:

    ~/nix/containers/gnome/build.sh --enter

That builds the `gnome-box` image (systemd, dbus-daemon, the full
`gnome-desktop` group, the `graphical-session.target` pull-in and the linger
pin — all baked in, see the Containerfile for why each is there), creates the
`gnome` container with the device and host-bus mounts, and verifies it. The
container is imperative on purpose: it is ~2 GB of desktop, and a rebuild
should not silently re-download it. Its storage is under
`~/.local/share/containers`, which impermanence already persists, so it
survives reboots.

To do this without a working login shell, use a real session so `XDG_RUNTIME_DIR`
exists:

    machinectl shell guest@

then run `build.sh` from there with `NO_DBX=1` in the environment, so the login
hook does not try to enter a container that does not exist yet.

If the container already exists from the old manual procedure, `build.sh`
says so and stops; pass `--recreate` to replace it with the image-built one.

### `dnf` in this box — noisy scriptlets, complete transactions

A plain `dnf install` prints alarming scriptlet output after unpacking:

    fchownat() of /dev/kvm failed: Operation not permitted
    Failed to set unit properties on systemd-udevd.service: Unit systemd-udevd.service is masked.

Two causes, both inherent to a rootless distrobox rather than anything wrong
with the packages:

- distrobox bind-mounts the host `/dev` (rslave), so udev's rules fire on host
  device nodes — `/dev/kvm`, `/dev/snd/*`, `/dev/vhost-*` — and try to chown them
  to gids that do not map inside the box's user namespace. `EPERM`.
- distrobox deliberately masks `systemd-udevd.service`, because a second udevd
  cannot bind the control socket. systemd's helper trips over the masked unit.

On Fedora 44 every trigger that can print this ends in `|| :`, so the noise
is harmless: a default-flags `dnf reinstall systemd-udev` printed exactly the
two lines above and still ended in `Complete!` (exit 0). `--setopt=
tsflags=notriggers` skips the whole trigger stage instead — the image keeps
it on its systemd/dbus bootstrap line only, and the desktop group install
runs stock triggers, because skipped file triggers are what made `mime.cache`
and the icon caches vanish in the first place (see the Containerfile header).
Use plain `dnf` for package work in the box; add the flag only to silence
scriptlet noise you do not want to read.

If you already ran it without the flag, check what landed rather than assuming
either way:

    rpm -q gnome-session gnome-shell mutter

`ls -l /dev/dri/renderD128` from inside the box is the device check worth
having: it is the one property the VM could not prove, and a `nobody:nobody`
owner there means the compositor cannot open the GPU.

To do this without a working login shell, use a real session so `XDG_RUNTIME_DIR`
exists:

    machinectl shell guest@

then run `build.sh` from there with `NO_DBX=1` in the environment, so the login
hook does not try to enter a container that does not exist yet.

If `gsettings` reads ever fail for no visible reason inside the box, check for
a root-owned dconf db (it gets that way if anything ever ran dconf as
box-root, e.g. an early `podman exec` without `--user`) and delete it.

## If `gnome` already exists, it is probably wrong

`distrobox enter` does not fail when the container is missing. It prints
`Create it now, out of image <default>?`, and with no terminal to answer — which
is exactly the greeter's situation — `read` gets EOF, the default answer is
taken, and it creates the container itself from its built-in default image
`registry.fedoraproject.org/fedora-toolbox:latest`, with **none** of the flags
above: no `--init systemd`, no dbus-daemon, no `/dev/dri`, no host bus mount.
The login then dies within seconds on a missing `/usr/bin/gnome-session`, and a
2 GB unusable container is left behind that every later login reuses.

The module now refuses to start when the container is missing, so this cannot
happen from the greeter again. If you are reading this because a container
exists but the session still fails, check it before trusting it:

    podman inspect gnome --format '{{.ImageName}} systemd={{.Config.SystemdMode}}'

`fedora-toolbox` with `systemd=false` means it is one of these accidental
containers. Delete it and create it properly:

    distrobox rm -f gnome

then run `build.sh` from the setup section above. A correctly created one
reports `localhost/gnome-box systemd=true`.

## First greeter login as guest

Do this with a way back in hand:

- Apply with `nh os test`, not `switch`, so a reboot reverts.
- Keep a root TTY logged in (`Ctrl+Alt+F3`) before touching the greeter.
- Log in as guest, confirm the desktop, log back out, log in again, and
  switch between `nithin` and `guest` without rebooting. The second login is
  the test that matters: `XDG_SESSION_ID` is per-login from PAM, and anything
  caching the old ID breaks. By construction nothing caches it — the
  dispatcher forwards the live environment, the box user manager never carries
  `XDG_SESSION_ID` (only the stable `XDG_SESSION_TYPE`/`XDG_CURRENT_DESKTOP`),
  and the dispatcher's EXIT trap stops the box session on logout so the next
  login starts clean — but verify it rather than trusting the design.

The manual equivalent of `build.sh`, for when the image needs debugging rather
than rebuilding — every flag here is load-bearing:

    distrobox create --name gnome --init \
      --additional-packages "systemd dbus dbus-daemon" \
      --image registry.fedoraproject.org/fedora:44 \
      --additional-flags "--device /dev/dri --device /dev/input"

Three things in that command line are load-bearing:

- **`--additional-flags`, not `--device`.** distrobox has no `--device` flag and
  fails with `Invalid flag '--device'`. `--additional-flags` does reach the
  runtime. Verify with `podman inspect gnome` and check two fields:

      podman inspect gnome --format '{{.ImageName}} systemd={{.Config.SystemdMode}}'

  `fedora:44` with `systemd=true` is correct. Two traps here: `HostConfig.Init`
  is *not* it (that field means an init binary like tini was injected, whereas
  distrobox's `--init systemd` becomes podman's `--systemd=always`), and
  `HostConfig.Devices` is **always** `[]` because distrobox passes
  `--privileged` and podman skips enumerating devices for privileged containers
  (`GetDevices` returns empty whenever priv is set). For the devices, run
  `distrobox create --verbose` and look for `Non-CDI device /dev/dri`, or just
  check the result from inside the box with `ls -l /dev/dri/renderD128`.
- **`dbus-daemon` is a separate package from `dbus`.** Without it the container
  has no working user bus for gnome-session to talk to.
- **The host system bus and session files are mounted into the box.** These
  are the two deliberate holes in the container boundary (see below), and
  without them nothing starts: mutter finds its seat through logind on the
  *system* bus, and validates `XDG_SESSION_ID` against the session *files*,
  and the box's own logind knows no seat and keeps no session files.
- **`registry.fedoraproject.org/fedora:44`** — current stable, GNOME 50. Fedora 43
  works too; 42 and older do not, because mutter removed its X11 backend in the 50
  cycle and this needs none.

## How the session starts

One greeter entry, `Name=Desktop`, whose `Exec` is a dispatcher that switches on
the user:

- `nithin` → `niri-session`, natively.
- `guest` → `distrobox enter --name gnome -- /usr/bin/gnome-session`.

That entry is a `services.displayManager.sessionPackages` member rather than an
`environment.etc` file, because that option is what makes NixOS copy the entry
into a store tree on `XDG_DATA_DIRS`, which is where the greeter looks.

The greeter only knows one `Name=`, so `XDG_CURRENT_DESKTOP` would be wrong for
one of the two users. The dispatcher overrides it per user rather than relying on
`DesktopNames=`, which is the entire reason it exists instead of two entries.

## Why this works at all, given GNOME 50 has no X11 backend

The obvious approach — share the host's X server, as the upstream distrobox
write-up does — is dead. That write-up is GNOME 42, where mutter had an X11
backend and the container's desktop was an X11 *client*; the `/tmp/.X11-unix`
chown workaround in it exists for that reason. Mutter dropped the X11 backend
outright in the 50 cycle, so there is no X11 route and no `--nested` either
(`mutter --help` documents `--display-server` as "rather than nested", and the
flag it would invert no longer exists).

What works instead is option B from the same write-up, which its Hyprland section
uses: the container's compositor takes the GPU itself.

    distrobox create ... --additional-flags "--device /dev/dri --device /dev/input -v /run/dbus/system_bus_socket:/run/dbus/system_bus_socket"

The container runs **mutter as a real Wayland display server**. Verified on
Fedora 44 in the test VM:

    Running Mutter (using mutter 50.5) as a Wayland display server
    Added device '/dev/dri/renderD128' (virtio_gpu) using no mode setting.
    GPU /dev/dri/renderD128 selected as primary
    Using Wayland display name 'wayland-0'

X11 applications still work: mutter starts XWayland for them. That is the
replacement for what the X11 backend used to provide.

The upstream caveat for this mode — "requires you to not have any other Wayland
sessions running" — is already satisfied, since only one user is logged in at a
time here.

## The two things that are easy to get wrong

Both cost real debugging time, so both are worth keeping.

**1. Device access is not the problem; the logind session is.** A rootless
container maps only its own user's uid and gid, so `/dev/dri/card0` appears as
`nobody:nobody 0660` — which *looks* like a permissions wall but is not one.
Inside a rootless container the user is root-mapped, so `test -w` always says
yes and means nothing; a real `open(O_RDWR)` succeeds, verified on this
machine's real GPU. Do not "fix" this with an ACL (udev has no ACL key at all —
`ACLS=` fails the build with `Invalid key 'ACLS'`) or with `MODE="0666"`, which
would make the primary GPU node world-writable for no reason.

The actual wall is one layer up. Mutter's native backend takes its display
devices through logind (`meta-launcher.c`: `TakeDevice` on the session's seat),
and it finds the session by trying `XDG_SESSION_ID`, then its own PID, then
the display, dying with "Failed to find any matching session" when none
resolve. The box's own logind can never satisfy this: its sessions are all
`type=unspecified`, and its `seat0` has `Devices: n/a`, because distrobox
masks `systemd-udevd` and no second udevd can bind the control socket
("Address already in use") — so no `ID_SEAT` tags ever exist in the box.

### greetd does not set `XDG_SESSION_ID`, so the dispatcher derives it

This is the single fact that broke the first hardware login, and it is not
obvious. greetd **never sets `XDG_SESSION_ID`**. `strings` on greetd 0.10.3
yields exactly three XDG variables:

    $ strings greetd | grep -oE 'XDG_[A-Z_]+' | sort -u
    XDG_SEAT
    XDG_SESSION_CLASS
    XDG_VTNR

greetd forwards the PAM environment verbatim and nothing in its stack adds the
id, so the variable mutter needs is simply absent. The symptom is deceptive:
every GNOME unit comes up normally and *then* the session dies, with

    gnome-shell: Failed to setup: Failed to find any matching session
    org.gnome.Shell@user.service: Failed with result 'protocol'
    Dependency failed for gnome-session@gnome.target

and, slightly earlier, the tell that it is an id problem rather than a
permissions one:

    gnome-session-service: Could not get session id for session. Check that
     logind is properly installed and pam_systemd is getting used at login.

The test VM missed this because the probes set `XDG_SESSION_ID` by hand.

So the dispatcher resolves the id itself, from its own cgroup: logind names
every session scope `session-<id>.scope`, and greetd runs the session command
as a direct child of the session leader, so the dispatcher's cgroup *is* the
session scope. Verified against a live login — greetd's leader for session 15
sat in `/user.slice/user-1000.slice/session-15.scope`, matching
`/run/systemd/sessions/15`.

Two constraints on that derivation, both learned the hard way:

- **It has to happen host-side.** Inside the box it cannot work: podman gives
  containers a private cgroup namespace, so `/proc/self/cgroup` there reads
  `/`, and the processes sit in a `libpod-*.scope` under no session at all.
- **The extraction needs `|| true`.** `writeShellApplication` runs with
  `errexit` and `pipefail`, so a no-match `grep` aborts the script at the
  assignment and the diagnostic that explains why never gets printed.

Also note the id is per *login*, never per user: it must never be cached in the
box, and in particular never pushed into the box's user manager with
`systemctl --user set-environment XDG_SESSION_ID=...`, because linger keeps that
manager — and its environment — alive across logouts.

One bus cannot serve two systems, so the box keeps its own and only the
session is pointed at the host's. Concretely:

- No system-bus socket is mounted into the box. Its own dbus-broker serves
  its logind, PID 1, polkit and user manager, so all of that works exactly as
  on a normal machine. (An earlier version of this setup did mount the host
  socket, and it broke the box itself: every box client of the system bus
  suddenly talked to the host, the box's logind could no longer start the
  box's user manager, and gnome-session died with "No session bus running!"
  before mutter ever ran.)
- The dispatcher exports
  `DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/host/run/dbus/system_bus_socket`
  before starting the session. GDBus honors that variable, so mutter and the
  session daemons talk to host logind while everything box-internal stays
  local. The socket is reached through distrobox's own host-root mount, which
  survives the box's init.
- The single host session *file* the login needs is rebound into the box from
  `/run/host` at login time (the dispatcher does it, one file, released on
  logout): `sd_session_is_active` -- which is how mutter validates
  `XDG_SESSION_ID` -- never talks to logind at all, it reads
  `/run/systemd/sessions/<id>` directly (`sd-login.c: file_of_session`; a
  missing file is the `ENXIO` "No such device or address" failure). The box
  has no such files of its own.

With that in place, a plain `distrobox enter` — no cgroup migration, no
privilege — starts a working compositor: session found, `TakeControl` granted
(the caller must be the box guest, i.e. the session owner uid, which is what
`distrobox enter` runs as by default), display modeset, rendered desktop.
Verified with screenshots. An earlier theory that the compositor must sit in
the host session scope turned out wrong: only the `XDG_SESSION_ID`+file path
matters, and it is cgroup-independent.

The deliberate holes in the container boundary are therefore per-session, not
per-container: the session sees the guest's host session state and can talk
to host system services as the unprivileged guest uid. D-Bus policy still
applies, so privileged operations are denied -- but enumeration (sessions,
devices) is visible, and there is no narrower option: logind is the only path
mutter accepts.

One more piece is needed for the *full* session that the compositor alone
does not need: something must start `graphical-session.target`. Nothing in
any unit file Wants or Requires it (verified by grep across
`/usr/lib/systemd/user`), yet `gnome-session-pre.target` Requires it and the
whole tree stays dead without it — gnome-session starts
`gnome-session@gnome.target`, finds `graphical-session-pre.target` inactive,
and quits watching it. On a GDM system whatever launches the session evidently
triggers it; since this setup replaces GDM, that step belongs here. The fix is
a three-line drop-in in the box (part of the one-time setup, below), which
makes the session target pull it declaratively — `RefuseManualStart` blocks a
direct start, so a `Wants=` is the only way in:

    mkdir -p ~/.config/systemd/user/gnome-session@gnome.target.d
    printf '[Unit]\nWants=graphical-session.target\nAfter=graphical-session.target\n' \
      > ~/.config/systemd/user/gnome-session@gnome.target.d/pull-graphical.conf

With that in place the full session comes up: 27 GNOME units running
(settings daemon components, keyring, portals), verified in the VM with a
rendered desktop to show for it. No PID-resolving component has failed yet;
if one ever does, the box's user journal is where it shows.

**2. Do not wrap anything in `dbus-run-session`.** An earlier version of the
dispatcher ran `dbus-run-session -- gnome-session`, on the theory that mutter
needs a session bus and `distrobox enter` provides none. Both halves are wrong
here: the container runs its own systemd `--user`, so the user bus already
exists, and `dbus-run-session` *replaces* it with a private one — which is
exactly what broke gnome-session with "Failed to upload environment to systemd".
Plain `distrobox enter` connects to the working user bus. The `set_gnome_env`
assertion that motivated the wrapper only fires when there is no bus at all
(seen once, running bare `podman run` without `XDG_RUNTIME_DIR`), never under
`distrobox enter`.

## The box inherits the host environment verbatim, so the session sanitises it

`distrobox enter` forwards the **entire** host environment into the box, and the
host is NixOS while the box is Fedora. The image itself ships everything the
desktop needs — verified with `rpm` and `ls` inside a running session:
`adwaita-cursor-theme-50`, `adwaita-icon-theme-50`, `gtk3`/`gtk4`/`libadwaita`,
Cantarell/Noto fonts, and `/usr/share/icons/Adwaita/cursors/left_ptr`. What the
first fully-running session was missing (cursor, icons, theme) was therefore
never a package problem — it was the leaked host variables, measured in the
session's own environment:

- `XCURSOR_PATH` was an all-Nix list (`~/.icons:…:/run/current-system/sw/share/icons`)
  **without `/usr/share/icons` in it at all**. When set, `XCURSOR_PATH`
  *replaces* the default search path, so the box's only cursor theme was never
  found: no pointer. This is the whole "cursor is missing" report.
- `XDG_DATA_DIRS`/`XDG_CONFIG_DIRS`/`TERMINFO_DIRS`/`INFOPATH`/`LIBEXEC_PATH`/
  `QTWEBKIT_PLUGIN_PATH`/`NIX_*`/`LESSKEYIN_SYSTEM` pointed at host directories,
  six of `XDG_DATA_DIRS`' entries nonexistent in the box.
- `GTK_PATH` pointed at host lib dirs — and **`/nix` is bind-mounted into the
  box** (`podman inspect`: `/nix <- /nix`), so those paths *resolve*: the box's
  GTK3/GTK4 would happily `dlopen` a host `.so` into a Fedora process.
- `LOCALE_ARCHIVE=/run/current-system/sw/lib/locale/locale-archive` — the host
  glibc's archive; the box's own is at `/usr/lib/locale` (verified present).
- `SYSTEMD_XKB_DIRECTORY=/etc/X11/xkb` — no such directory in the box; xkb data
  lives at `/usr/share/X11/xkb` (verified).
- `PATH` was entirely host profile directories.

So the session enter runs one sanitisation pass over its environment, per
variable:

1. Value mentions a host Nix path (`/nix/store`, `/nix/profile`,
   `~/.nix-profile`, `/nix/var/nix`, `/run/current-system`,
   `/etc/profiles/per-user`) → drop it. Two exceptions are *repaired* instead of
   dropped: `PATH` is reset to `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin`,
   and `SHELL` is repointed at the user's shell in the box (`getent`), because
   dropping those would leave children with no command search path and no login
   shell.
2. Absolute-path value with no entry that exists in the box → drop it (terminfo,
   locales and xkb all fall back to working box defaults — verified above).
3. `WAYLAND_DISPLAY` whose socket is not in the box runtime dir → drop it; the
   box compositor has not started yet, so the value can only be a host leftover.

`/run/host` is deliberately **not** a marker — it is how the session reaches the
host system bus. The `DBUS_*` addresses start with `unix:`, not `/`, so they are
kept by rule 2 regardless; `XDG_SESSION_ID`, `XDG_CURRENT_DESKTOP`, `HOME` and
`LANG` are kept by design.

The pass applies to the session process **and** to the box user manager
(`systemctl --user unset-environment`/`set-environment`), because the units —
`org.gnome.Shell@user.service` included — inherit the *manager*'s environment,
and gnome-session's activation upload only sends the variables it *has*: a value
merely unset locally would survive in the manager from the first enter's PAM
import and reach gnome-shell anyway (that is exactly how `XCURSOR_PATH` got
there). The transcript logs the result as `inner: host env stripped: …`.

Known wrinkle: any *later* `distrobox enter` (an interactive shell login, say)
re-imports some session variables into the manager mid-session. Already-running
units are unaffected (they captured their environment at start), the unit
drop-ins pin `XDG_SESSION_ID` on every service in the session target's closure
regardless of what the manager carries, and the session enter re-sanitises on
the next login. The closure-wide pin exists because one unit is never enough:
with the drop-in on gnome-shell only, `gsd-media-keys` spawned without the id.
(Note: closing that gap did not enable screen lock — lock additionally
requires GDM upstream, see STATUS; the pin still stands on its own as the
only channel that survives gnome-session's activation-env upload.)

## `/tmp/.X11-unix`

Deliberately untouched. The upstream write-up chowns it to the user because its
GNOME was an X11 client; this one's compositor is native and does not need it.
Two users share `/tmp`, so a blanket chown to `guest` would be a footgun. If
XWayland ever does complain, the smallest fix is a `systemd.tmpfiles` rule
creating `/tmp/.X11-unix` as `1777 root:root` — sticky, not owned by anyone.

## Testing

`tests/guest-desktop/`, two harnesses for two different questions.

    ./host-probe.sh gpu      # device access + mutter, on this machine's real GPU
    ./host-probe.sh clean    # remove the throwaway container and image
    ./vm-up.sh               # boot the test VM (serial console + SPICE)
    ./vmg send '<command>'   # type at the VM's serial console

Use `host-probe.sh` for anything to do with the GPU. The VM's GPU is virgl —
software GL 4.2 — so it cannot answer those questions, and using it anyway
produced two wrong conclusions that the real GPU immediately reversed:

- "rootless podman `--device` cannot reach card0" — false; the real cause was a
  plain `--volume` bind mount, which leaves host gids unmapped.
- "`-r`/`-w` inside the container proves access" — false, as above.

The VM is for the one thing the host cannot test: whether the greeter hands off to
this session correctly.

Long commands go through `vmg`, which stages a script over the virtiofs exchange
directory. Use a fresh filename per run; a file chowned to `guest` by an earlier
run cannot be overwritten.

## Not verified

- Whether mutter can claim a VT and mode-set the real panel, rather than the
  VM's virtual output. Everything else in the chain is proven in the VM.
- Logging out of the greeter session and back in as `nithin`, which is the
  regression check for `/tmp` ownership and XWayland.
- Long-run stability (lingering, idle/screen-lock behavior without GDM —
  expect a "screen lock requires GDM" notice, which is cosmetic).