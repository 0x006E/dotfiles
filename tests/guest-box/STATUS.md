# Guest box: where this stands

Written at the end of the first working session, so the next one starts from
facts rather than from archaeology. Everything here was measured, not assumed.

## Run it

```sh
cd tests/guest-box
./vm-up.sh            # keeps the disk, so the installed box survives
./vm-up.sh --reset    # clean NixOS install, to test a first login
```

Then, in a browser (this is the guest's real screen, clickable):

```
http://127.0.0.1:6080/vnc.html?autoconnect=1&resize=scale&host=127.0.0.1&port=6081&path=
```

The `host`, `port` and empty `path` are all load-bearing — see the comment in
`vm-up.sh`. QEMU's VNC-over-WebSocket answers only on exactly `/`.

Three ways to see what the guest is doing:

| what | how |
|---|---|
| screen, clickable | the noVNC URL above |
| screen, scripted | `./vm-shot.sh /tmp/shot.png` (QMP screendump, no browser) |
| logs and a shell | `tail -f /tmp/guest-box-vm.log` |

`vm-console.py` gives the guest's serial console a pty, so it is both a log and
typeable: `vm-console.py console --send 'ls\n'`. Logging in as root there
(`root`/`root`, test-only) is how every failure below was diagnosed — the guest
account's shell *is* the box session, so it is no use for debugging.

## What is verified working

- The guest's login shell starts the session: niri comes up, takes X display
  `:0`, and the box launcher runs.
- The niri-X11 handshake, which took three attempts to get right. niri binds
  `/tmp/.X<n>-lock` holding **its own pid** at startup and spawns
  xwayland-satellite only when the first X client connects. So niri must start
  *first*, and the display number is read out of that lock file — which is also
  what keeps the guest off the owner's screen when the owner is logged in.
- Rootless podman runs: `security.shadow` for newuidmap, the *NixOS-built*
  podman (not `pkgs.podman` — only the configured one has `/run/wrappers` on its
  PATH), and distrobox's own script dependencies (sed, awk, tar, mount, …)
  supplied by the session's PATH.
- The image pull, the MATE install, and the init hook all complete.
- Changing `services.guest-box.image` rebuilds the box, from the log:
  `image changed (quay.io/... -> docker.io/library/ubuntu:24.04), rebuilding`.
- `nix flake check` passes; the VM builds.

## What is *not* verified yet

**The MATE desktop has never been seen pixel-for-pixel** -- and it cannot be,
in this VM. VNC shows the emulated VGA text console because niri cannot take
over graphics without GPU drivers (the MESA/`dri_gbm.so` errors in the session
log); the desktop exists only inside Xwayland's buffers. Rootless Xwayland has
no root pixmap (`import -window root` fails), and clients never draw without
frame callbacks that never come headless. Pixels need the laptop.

What the VM *can* verify instead, and has:

- MATE session, panel, caja, settings-daemon run as X clients on :0.
- An app window (pluma, 650x720) gets managed geometry -- niri tiles X windows.
- niri owns the WM selection *by design* (xwayland-satellite holds WM_S0 and
  forwards management to niri). marco can never run here: it starts, sees
  "already has a window manager", spins at 100% on a GLib assertion and dies.
  An autostart entry for it was tried three ways (WindowManager phase never
  runs, OnlyShowIn hides it, plain entry starts a zombie) -- all wrong. There
  is deliberately no marco; GTK apps draw their own decorations and niri frames
  the rest.

## Still open (load-bearing, VM-testable)

1. Isolation: can the box read the stand-in owner's `/home/nithin/private.txt`?
2. Do `host-spawn` / `distrobox-host-exec` refuse (exit 126)?
3. polkit: which power/wifi/mount calls allow and deny?
4. Logout ends the session; reboot gives a fresh box HOME.
5. Chrome launches (pluma proves X apps run; chrome's sandbox is the question).

## Fixes made today, each one found by a failing run

Every one of these was a silent failure or a wrong-but-plausible-looking thing:

- **xwayland-satellite cannot start before a compositor** (`NoCompositor`
  panic). The session started it standalone; it is a client of a Wayland
  compositor. Now niri owns it.
- **`${lock#/tmp/.X}`** left `-lock` on the display name: `DISPLAY=:0-lock`.
- **The launcher had its own `runtimeInputs`** containing `pkgs.podman`, which
  `writeShellApplication` *prepends* to the session PATH, shadowing the
  NixOS-configured podman. Rootless podman then could not find newuidmap.
- **`--yes` missing** from `distrobox create`, so it sat at an interactive
  "pull the image now? [Y/n]" prompt with no tty.
- **`/usr/bin/distrobox-host-exec` is a read-only bind mount**, so it can be
  neither written nor unlinked ("Device or resource busy"). The host-exec hole
  is now closed by *shadowing* it from `/usr/local/bin`, which comes first in
  PATH, rather than by replacing it.
- **A Nix `''` string strips its common indentation.** One line indented 4
  instead of 6 moved every heredoc terminator, and the whole `guest-box-tools`
  package silently became a single 61-line `guest-shutdown`. The helpers are one
  derivation per file now, with no nested heredoc. Same trap is called out on
  the init hook.
- **`symlinkJoin` does not merge files.** `writeShellScript` outputs a file, and
  `lndir` only links directories, so the join was an empty directory. The
  tools package links its parts explicitly.
- **`/usr/local/share/applications` does not exist** in plain ubuntu — the
  toolbx images have it. Present in the toolbx image, absent in the one the
  config now uses.
- **The session never ended when the box died.** `niri msg action quit` cannot
  work from niri's *parent*: niri exports `WAYLAND_DISPLAY` only to what it
  spawns. Now `wait -n` on niri and the box, and the trap tears the other down.
- **The host's SHELL leaks into container init and kills every restart.**
  Login sets SHELL to the session script; distrobox-init resolves it inside the
  box, and on every start after the first `SHELL=$(command -v ...)` fails under
  `set -e` and the container exits 1 forever. Fixed with `export SHELL=/bin/bash`
  plus a narrowly-matched one-time rebuild. The first version compared against
  `/bin/bash` exactly, but healthy boxes store bare `bash` -- an every-login
  rebuild loop caught from the session log before it shipped.
- **Init hooks (and the package list) bake in at creation.** Editing either
  silently does nothing to existing boxes. Both are stamped into container
  labels; the launcher rebuilds on mismatch.
- **The hook writes icons as root; the launcher wipes as guest.** `rm` failed
  with Permission denied and the wipe was a lie. The hook chowns Desktop to the
  box HOME's ownership, last.
- **`podman exec` defaults to container-root, a different host uid** under
  keep-id mapping than the X server's -- every manual X client failed with a
  misleading "Authorization required" until `--user 1000` was used.
- Test-harness bugs, all of which cost real time: the runner was started in the
  read-only store (so qemu-img could not create the disk); websockify drags in
  numpy; noVNC and QEMU's websocket were both on port 6080, and QEMU won, so
  every `vnc.html` 404'd; the noVNC web root is `share/webapps/novnc`, not the
  package output; and a stale static server holding the port answers 404s that
  look exactly like broken noVNC.

## Packaging facts for noble, all learned the hard way

- `ubuntu-mate-desktop-minimal` does not exist. So does `mate-session`.
- `/usr/bin/mate-session` ships in **`mate-session-manager`**, a hard Depends of
  `mate-desktop-environment-core`. `mate-desktop` is only the About and Colour
  Settings dialogs.
- `mate-desktop-environment` (metapackage): 490 MB, 716 packages.
  The `-core` set plus four apps: 307 MB, 579 packages.
- Toolbox images contain no desktop and no browser at all. Measured inside the
  image: `ubuntu-toolbox:24.04` is 196 MB / 378 packages / zero matches for
  `mate-*`, `marco`, `caja`, `xfce`, `gnome-shell`, `firefox`, `chromium`.
  `library/ubuntu:24.04` is 29 MB of the same userland.
- `linuxserver/webtop:ubuntu-mate` (1.4 GB) does have MATE and Firefox, but runs
  its own Xvfb to be *served to a browser*; its desktop never reaches our
  Xwayland.
- Chrome: not an apt repo (a signing key in the box would take the whole
  creation down if it failed) and not a snap (snapd cannot run in a container,
  and Ubuntu's firefox and chromium-browser are both snap stubs). A plain .deb
  from dl.google.com, fetched with wget, best-effort.

## The box's first login costs ~10 minutes, once

It is once: the container persists in `/persist/home/guest` and the launcher
only creates it when it does not exist. The guest sees the progress on the
console, because until niri takes the VT the console *is* the screen, and a
black screen with nothing to read is the one failure a kiosk cannot explain.
