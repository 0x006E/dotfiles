#!/usr/bin/env bash
# Build the guest's GNOME box image and create the distrobox container from it.
#
#   ./build.sh                 # build + create, container name "gnome"
#   ./build.sh --recreate      # delete an existing container first
#   ./build.sh --enter         # build, create, then drop into it
#
# Run as `guest`. The container's storage is under
# ~/.local/share/containers, which impermanence already persists.
#
# Two steps, because they happen at different times: packages go into the image
# (a Dockerfile, reproducible, diffable, and it does not fight the box at
# runtime), while devices and host mounts are properties of the *container* and
# can only be set when podman creates it.
set -euo pipefail

name=gnome
image="localhost/${name}-box"
recreate=0
enter=0

for arg in "$@"; do
  case "$arg" in
    --recreate) recreate=1 ;;
    --enter) enter=1 ;;
    *) name="$arg"; image="localhost/${name}-box" ;;
  esac
done

here="$(dirname "$(readlink -f "$0")")"

if ! command -v podman > /dev/null; then
  echo "podman is not on PATH; this has to run on the host as $USER" >&2
  exit 1
fi

# newuidmap/newgidmap come from /run/wrappers/bin, which the podman wrapper puts
# on PATH itself. If podman is the raw binary rather than the wrapper, a
# rootless container cannot map the user's subuid range and fails obscurely.
if [ ! -e /run/wrappers/bin/newuidmap ]; then
  echo "warning: /run/wrappers/bin/newuidmap is missing; rootless may fail" >&2
fi

echo "==> building $image from $here/Containerfile"
podman build -t "$image" "$here"

if [ "$recreate" = 1 ] && podman container exists "$name"; then
  echo "==> removing the existing container $name"
  # `distrobox rm` rather than `podman rm`: it also clears the box's
  # /etc/hostname and /etc/resolv.conf bind mounts, which otherwise survive as
  # broken mounts onto a path that no longer has a container behind it.
  distrobox rm --force "$name"
fi

if podman container exists "$name"; then
  echo "==> container $name already exists (pass --recreate to replace it)"
else
  echo "==> creating container $name from $image"
  # Devices only. The host system bus and the session files are deliberately
  # NOT mounted here (an earlier version did both): the socket bind hijacks
  # the box's own system bus -- every box client of it, including the box's
  # logind and PID 1, suddenly talks to the host, so the box can no longer
  # start its own user manager and gnome-session dies with "No session bus
  # running!" -- and the sessions-dir bind is shadowed by the box's own
  # /run/systemd anyway. The session reaches the host bus per-login through
  # DBUS_SYSTEM_BUS_ADDRESS (see the module), and the one session file it
  # needs is rebound at login from /run/host.
  distrobox create --yes --name "$name" --init --image "$image" \
    --additional-flags "\
      --device /dev/dri \
      --device /dev/input"
fi

# Check the two things that are silent when wrong. Neither is a valid check on a
# privileged container: HostConfig.Devices is always [] because podman skips
# device enumeration for privileged containers, and HostConfig.Init means "an
# init binary was injected", not "systemd is the box's init". See
# docs/guest-desktop.md.
echo "==> verifying"
printf 'image:   %s\n' "$(podman inspect "$name" --format '{{.ImageName}}')"
printf 'systemd: %s\n' "$(podman inspect "$name" --format '{{.Config.SystemdMode}}')"
printf 'session: %s\n' "$(podman inspect "$name" --format '{{.ImageName}}' > /dev/null && echo ok)"

if [ "$enter" = 1 ]; then
  exec distrobox enter --name "$name"
fi