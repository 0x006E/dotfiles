# Per-user desktop sessions behind the one greeter.
#
# There is exactly one session in the greeter's picker, named `Desktop`, and it
# dispatches on the user that logged in:
#
#   nithin -> niri, natively, from the host. Nothing about this branch touches a
#             container; it exists so that the owner's login is the *same* code
#             path as the guest's, which means one entry to test rather than two.
#   guest  -> GNOME, inside a rootless distrobox container.
#
# GNOME is not installed on the host and must not be. It lives in the container,
# which the guest creates once and imperatively (see docs/guest-desktop.md);
# nothing here builds or pulls an image, because a 2 GB desktop is not something
# a rebuild should redo behind the user's back.
#
# Why a container at all, and why GNOME: see docs/guest-desktop.md. The short
# version is that the guest is a second person using the machine, and a rootless
# container is the only boundary available that needs no privileges.
{
  delib,
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.services.guest-desktop;

  # The niri to hand the owner. Read from the niri module so the dispatcher can
  # never disagree with `programs.niri.package` about which compositor is
  # installed; the fallback is only for the case where niri is not installed at
  # all (the test VM), where the owner branch simply is not used.
  niriPkg = if config.programs ? niri then config.programs.niri.package else pkgs.niri;

  # podman as the system configures it, not a store-path podman: the wrapper is
  # what puts /run/wrappers/bin (newuidmap, newgidmap) on PATH, and that is what
  # makes a *rootless* container able to use this user's subuid range.
  podmanPkg = config.virtualisation.podman.package;

  # The whole session entry, in one script, because the greeter only ever runs
  # one Exec and there is no per-user session concept to hook into.
  #
  # Every path is absolute. greetd does not run the session through a shell with
  # a login PATH: it builds `exec <argv joined by spaces>` and hands it to
  # /bin/sh -c, so anything resolved via PATH is at the mercy of whatever PATH
  # survived PAM.
  dispatcher = pkgs.writeShellApplication {
    name = "desktop-session";
    # Nothing here: a runtimeInput would be prepended to PATH and could shadow
    # the system podman, which is the one that knows about newuidmap.
    runtimeInputs = [ ];
    text = ''
      case "$(id -un)" in
        ${cfg.ownerUser})
          # niri, exactly as the stock Niri entry runs it: niri's own
          # resources/niri.desktop is `Exec=niri-session`, a bare token.
          # XDG_CURRENT_DESKTOP/XDG_SESSION_DESKTOP are also set by the greeter
          # from DesktopNames= below; they are repeated here so this branch does
          # not depend on the entry carrying the right DesktopNames, and so the
          # two branches stay symmetrical.
          export XDG_CURRENT_DESKTOP=niri
          export XDG_SESSION_DESKTOP=niri
          exec ${niriPkg}/bin/niri-session
          ;;
        ${cfg.guestUser})
          # Overrides the greeter's niri-derived values, which is the entire
          # reason the dispatcher exists rather than two session entries.
          # XDG_SESSION_TYPE stays what the greeter set (wayland, from the
          # wayland-sessions directory), and XDG_SESSION_ID stays the guest's
          # real logind session: distrobox enter forwards both, and mutter
          # needs them to find the session on the host logind (see
          # containerFlags below).
          export XDG_CURRENT_DESKTOP=GNOME
          export XDG_SESSION_DESKTOP=gnome
          # A bare gnome-session, deliberately NOT under dbus-run-session: the
          # container runs its own systemd --user, so the user bus already
          # exists, and dbus-run-session would *replace* it with a private bus
          # -- which is exactly what broke gnome-session with "Failed to upload
          # environment to systemd". The path is inside the container, hence not
          # a store path.
          exec ${lib.getBin pkgs.distrobox}/bin/distrobox enter --name ${cfg.containerName} -- \
            ${cfg.gnomeSessionCommand}
          ;;
        *)
          printf 'desktop-session: no desktop session defined for user %s\n' "$(id -un)" >&2
          exit 1
          ;;
      esac
    '';
  };

  # The greeter entry. It has to be a session *package* rather than a plain
  # environment.etc file, because services.displayManager.sessionPackages is
  # what makes NixOS copy the entry into a store tree (lndir) and put that tree
  # on XDG_DATA_DIRS -- which is where the greeter looks for sessions.
  #
  # `providedSessions` is a plain derivation attribute, NOT passthru: nixos reads
  # it as `p.providedSessions` (services/display-managers/default.nix) and the
  # option's own type check is `p ? providedSessions`. A passthru attribute is
  # not visible there and the configuration does not evaluate. The value must be
  # the file's stem, and nixos asserts that <value>.desktop exists in here.
  sessionPackage = pkgs.runCommand "guest-desktop-session" { providedSessions = [ "desktop" ]; } ''
    mkdir -p "$out/share/wayland-sessions"
    cat >"$out/share/wayland-sessions/desktop.desktop" <<'DESKTOP'
    [Desktop Entry]
    Name=${cfg.sessionName}
    Comment=Per-user desktop session
    Exec=${lib.getExe dispatcher}
    Type=Application
    DesktopNames=niri
    DESKTOP
  '';
in
delib.module {
  name = "desktop.guest-desktop";

  # Enable/disable is the delib feature gate: the host sets
  # `desktop.guest-desktop.enable` in its manifest. The other knobs are ordinary
  # NixOS options under `services.guest-desktop`, declared unconditionally below
  # because they are read from `config` above, outside the enable gate.
  options = delib.singleEnableOption true;

  nixos.always = {
    options.services.guest-desktop = {
      ownerUser = lib.mkOption {
        type = lib.types.str;
        default = config.myconfig.constants.username;
        defaultText = "myconfig.constants.username";
        description = "User whose session is niri on the host.";
      };

      guestUser = lib.mkOption {
        type = lib.types.str;
        default = "guest";
        description = "User whose session is GNOME in the distrobox container.";
      };

      containerName = lib.mkOption {
        type = lib.types.str;
        default = "gnome";
        description = ''
          distrobox container name. The guest creates this container once, by
          hand; this option only names it afterwards, so a mismatch shows up as
          distrobox failing to find the container rather than as a silent
          fallback to the host shell.

          The container is Fedora 44 and must be created with:

            distrobox create --name ${cfg.containerName} --init \\
              --additional-packages "systemd dbus dbus-daemon" \\
              --image registry.fedoraproject.org/fedora:44 \\
              --additional-flags "${lib.concatStringsSep " " cfg.containerFlags}"

          Fedora 44 ships gnome-shell and mutter 50.5. dbus-daemon is a separate
          package from dbus and is easy to miss; without it the container has no
          working user bus for gnome-session to talk to.

          See docs/guest-desktop.md for the full one-time procedure.
        '';
      };

      gnomeSessionCommand = lib.mkOption {
        type = lib.types.str;
        default = "/usr/bin/gnome-session";
        description = ''
          Command run *inside* the container. A container path, not a store
          path: it is resolved by the container's own filesystem.

          It runs against the container's own systemd --user, which is already
          up (the box runs systemd as init): do NOT wrap it in dbus-run-session,
          which would replace the working user bus with a private one and break
          gnome-session with "Failed to upload environment to systemd".
        '';
      };

      containerFlags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "--device"
          "/dev/dri"
          "--device"
          "/dev/input"
          "-v"
          "/run/dbus/system_bus_socket:/run/dbus/system_bus_socket"
        ];
        description = ''
          Devices and mounts passed into the container when it is created.

          These go through distrobox's --additional-flags, not a --device flag:
          distrobox has no --device option and fails with "Invalid flag
          '--device'". --additional-flags does reach the runtime, which is
          checkable with `podman inspect <name> --format
          '{{json .HostConfig.Devices}}'` (it must be non-empty).

          Why --device rather than --volume for /dev/dri: /dev/dri is
          bind-mounted by distrobox implicitly, which makes the devices
          *visible* but leaves the host's gid (video, 26) unmapped inside a
          rootless userns, so /dev/dri/card0 ends up nobody:nobody 0660 and
          cannot be opened. Passing the device explicitly makes the runtime set
          it up with permissions the container user actually has. The symptom
          to recognise is a container where `ls /dev/dri` works and open(O_RDWR)
          on card0 does not.

          Why the host system bus is mounted: mutter takes its display devices
          through logind (`meta-launcher.c`: TakeDevice on the session's seat),
          and it finds the session through the *system* bus -- the box's own
          logind knows no seat, because distrobox masks systemd-udevd and no
          second udevd can bind the control socket, so no ID_SEAT tags ever
          exist in the box. With the host bus mounted, the box sees the guest's
          real host session and mutter starts with no errors. Without it the
          shell dies with "Failed to find any matching session".

          This is the one deliberate hole in the container boundary: the box can
          talk to host system services. D-Bus policy still applies, and the box
          presents as the unprivileged guest uid, so privileged operations are
          denied -- but enumeration (sessions, devices) is visible. There is no
          narrower option: logind is the only path mutter accepts.
        '';
      };

      sessionName = lib.mkOption {
        type = lib.types.str;
        default = "Desktop";
        description = ''
          The Name= of the greeter entry. Must match the greeter's
          `[session].default` setting below, which is set from this option, and
          which the greeter matches against Name= (not against the filename).
        '';
      };

      containerShell = lib.mkOption {
        type = lib.types.str;
        default = "/bin/bash";
        description = ''
          Shell started inside the container for an interactive login. A
          container path, resolved by the container's filesystem.

          distrobox mirrors the host login shell into the container, so this
          only has to name something that exists in there.
        '';
      };

      autoEnterContainer = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether an interactive login for the guest drops straight into the
          container. See programs.bash.loginShellInit below for what that does
          and, more importantly, what it refuses to do.
        '';
      };
    };
  };

  nixos.ifEnabled =
    { ... }:
    {
      # `guest`'s login shell.
      #
      # Two independent reasons, both load-bearing:
      #   * greetd runs the session with SHELL set from /etc/passwd, and
      #     niri-session re-execs itself through the login shell, so this value
      #     is what the guest's shell is everywhere.
      #   * distrobox-init reads $SHELL to decide which shell to install and
      #     resolve *inside* the container, falling back to `apt-get install
      #     <basename>` when it cannot find it. The default for a NixOS user is
      #     pkgs.shadow, whose basename does not exist in Fedora.
      users.users.${cfg.guestUser} = {
        shell = pkgs.bash;
        # `render` is what makes /dev/dri/renderD* usable, which is how the
        # container's compositor reaches the GPU. `video` and `audio` were
        # already there for the old LXQt kiosk and still apply.
        #
        # Deliberately NOT `input`: the container may need to read input devices
        # to drive libinput, but that group also grants read access to the
        # owner's keyboard and mouse outside the container. Adding it is a
        # decision to make once it is known to be needed, not a default.
        extraGroups = [
          "video"
          "audio"
          "render"
        ];
      };

      # No udev rule here, deliberately.
      #
      # A rootless container maps only its own user's uid and gid, so the host's
      # video group (gid 26) does not exist inside it and /dev/dri/card0 arrives
      # as nobody:nobody 0660, which open(O_RDWR) refuses. That looks like it
      # needs an ACL or a world-writable mode, and it does not: the mode is
      # 0660 *with a uaccess ACL*, granted by logind to whichever user holds an
      # active session on the seat. That is why the owner can open card1 here
      # (getfacl shows user:nithin:rw-, from `loginctl` listing them as a seat0
      # user) while card2, which nobody holds, has no such ACL.
      #
      # So the guest needs what the owner already has: a real session on seat0,
      # which greetd gives it. There is deliberately no ACLS line here -- udev has
      # no ACL key at all (it fails the build with "Invalid key 'ACLS'"), and a
      # 0666 rule would make the primary GPU node world-writable to every local
      # user to solve a problem that does not exist.
      #
      # The symptom if this ever regresses: mutter logs "Failed to initialize
      # accelerated iGPU/dGPU framebuffer sharing: Not hardware accelerated", or
      # the container lists /dev/dri but cannot open card0. Note that `ls` and
      # `test -w` both lie here -- inside a rootless container the user is
      # root-mapped, so -w is always true. Only a real open() tells the truth.

      # Rootless podman. security.shadow is what puts newuidmap/newgidmap with
      # setuid in /run/wrappers/bin, and without it the guest's subuid range
      # cannot be mapped, so container images containing files owned by uids
      # outside 0-65535 cannot be unpacked.
      #
      # NixOS allocates that range automatically for any isNormalUser
      # (config/users-groups.nix: autoSubUidGidRange), so nothing else is needed
      # for the guest account itself.
      security.shadow.enable = true;
      virtualisation.podman.enable = true;

      # Container storage ends up in the guest's home, which impermanence
      # persists, so the image is downloaded once rather than on every boot.
      #
      # The storage driver is pinned to overlay + fuse-overlayfs because that
      # path lands on btrfs (/persist): native overlayfs cannot use btrfs as its
      # upper layer without trusted.* xattrs, and podman's automatic btrfs graph
      # driver is not reliable for a plain directory that is not a subvolume.
      virtualisation.containers = {
        enable = true;
        containersConf.settings.storage.driver = "overlay";
        containersConf.settings.storage.options.overlay.mount_program =
          "${lib.getBin pkgs.fuse-overlayfs}/bin/fuse-overlayfs";
      };

      # distrobox on PATH for the guest, for the one-time creation commands in
      # docs/guest-desktop.md. The dispatcher and the login hook below use
      # absolute store paths and do not depend on this.
      environment.systemPackages = [
        pkgs.distrobox
      ];

      services.displayManager.sessionPackages = [ sessionPackage ];

      # Make the dispatcher the greeter's default session. Keyed on Name=, which
      # is what the greeter matches: findSessionIndex compares against the
      # entry's Name, never its filename. Resolution order is --session, then
      # [session].default, then [session].last, then whatever is discovered
      # first -- so this is the stable one of the two, [session].last being
      # runtime state the greeter rewrites.
      services.displayManager.noctalia-greeter.settings.session.default = cfg.sessionName;

      # An interactive login for the guest lands in the container.
      #
      # Deliberately a login hook and NOT a wrapper login shell: greetd starts
      # sessions through the user's shell with -c, and distrobox mirrors the
      # host login shell into the container, so replacing the shell with a
      # wrapper risks breaking both the greeter login and container entry.
      #
      # Every guard below is load-bearing, because /etc/profile is not only read
      # by interactive logins. greetd runs
      #   [ -f /etc/profile ] && . /etc/profile; ...; exec <session>
      # under /bin/sh -c before *every* session it starts, for every user, and
      # niri-session re-execs itself through a login shell as well. A hook that
      # fired there would replace the session with a container, or replace the
      # greeter's exec with nothing at all.
      #
      # Note what this must never do: exit. It runs in the middle of
      # /etc/profile, so a non-zero exit or an `exit` would abort the rest of
      # the profile and, in greetd's case, stop the session from ever starting.
      # Falling through is always safe; exec only happens on the happy path.
      programs.bash.loginShellInit = lib.mkIf cfg.autoEnterContainer ''
        # Only the guest: the owner's sessions must never touch a container.
        if [ "$(id -un)" = "${cfg.guestUser}" ]; then

          # Only an *interactive* shell, and the only branch here does anything:
          # a non-interactive shell matches no pattern, falls out of the case
          # and runs none of it. This is the guard that keeps greetd's
          # non-interactive `sh -c` (which sources /etc/profile) out, and that
          # keeps `ssh guest some-command` and every script out.
          #
          # An earlier version of this had `*i*) ;;` and `*) ;;` -- two empty
          # branches, which gates nothing at all -- and would have replaced
          # every greetd session with a container.
          case $- in
            *i*)
              # Only once, and only from outside: CONTAINER_ID is set by
              # distrobox inside the container, so this also makes a shell
              # started from within the container a plain shell instead of an
              # infinite exec loop.
              if [ -z "''${CONTAINER_ID:-}" ] && [ -z "''${NO_DBX:-}" ]; then
                # Only if the guest already created it. Until then an interactive
                # login has to stay a usable host shell, otherwise the one-time
                # setup in docs/guest-desktop.md would have to fight a hook that
                # keeps trying to enter a container that does not exist.
                if ${lib.getBin podmanPkg}/bin/podman container exists ${cfg.containerName}; then
                  # Plain enter, same as the greeter path: the container's user
                  # bus is already up, and wrapping the shell in
                  # dbus-run-session would shadow it.
                  exec ${lib.getBin pkgs.distrobox}/bin/distrobox enter --name ${cfg.containerName} -- \
                    ${cfg.containerShell}
                fi
              fi
              ;;
          esac
        fi
      '';
    };
}
