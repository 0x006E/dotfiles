# Guest kiosk: the `guest` account's whole session is an Ubuntu MATE desktop
# running in a rootless distrobox, shown on an Xwayland instance hosted by a
# bare niri session.
#
# Why this shape:
#   * rootless podman is the security boundary. The container's root is the
#     guest's uid, so `sudo` inside the box installs packages and nothing
#     else. A *rootful* distrobox would bind-mount / and be a full host hole.
#   * host-spawn / distrobox-host-exec (arbitrary host command execution) are
#     replaced by stubs in the box. The only host contact left is the D-Bus
#     system bus, where every privileged call is polkit-checked -- exactly the
#     authority the guest already has in its own host session.
#   * /home/nithin and /persist/home/nithin are 0700, so plain DAC keeps the
#     guest out of the owner's files. Nothing of the owner's is bind-mounted
#     into the box.
#   * MATE is X11-only, so it runs on Xwayland and Marco manages its windows
#     inside X; niri is just the display.
#
# What gets wiped, and when: the box's HOME (--home, on the ephemeral root) is
# recreated on every login, so nothing a guest creates survives logout or
# reboot. The container's filesystem (the installed desktop) lives in
# /persist/home/guest and does persist, which is what makes the one-time
# download cost a one-time cost.
#
# Structure: the options are declared unconditionally (nixos.always) so the
# file-level bindings below can read them, and everything derived from them
# lives in that let -- denix wraps an ifEnabled body in mkIf, so it has to be a
# plain attribute set and cannot use a module lambda for config/lib/pkgs.

{
  delib,
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  # The account this kiosk session belongs to (not the owner).
  guestUser = config.services.guest-box.user;
  boxCfg = config.services.guest-box;
  logFile = "/var/log/guest-box/${guestUser}.log";

  # Everything the session runs is addressed by absolute store path, so it never
  # depends on whatever environment greetd or getty hands over.
  #
  # xwayland-satellite is here for niri, not for us: niri runs its own
  # integration (it binds the X11 socket at startup and spawns the satellite
  # when the first X client connects), looking the binary up in PATH, and it
  # silently has no X11 support at all if it is missing.
  # distrobox is shell scripts written for a normal distribution: it calls sed,
  # awk, tar, mount and friends by bare name and assumes /usr/bin has them.
  # NixOS' PATH is curated, so the session has to bring them itself. This is the
  # list those scripts actually use that NixOS' PATH does not already cover
  # (coreutils and findutils are in sessionPath above).
  distroboxTools = with pkgs; [
    gnused
    gnugrep
    gawk
    gnutar
    xz
    glibc
    util-linux
    systemd
  ];

  sessionPath = lib.makeBinPath (
    [
      pkgs.bash
      pkgs.coreutils
      pkgs.distrobox
      # Not pkgs.podman: the NixOS module builds its own podman (a different
      # store path) with /run/wrappers -- where newuidmap/newgidmap live -- on
      # its PATH. Plain pkgs.podman has no such wrapper, and rootless podman
      # refuses to start without those two.
      podmanPackage
      pkgs.dex
      pkgs.libnotify
      pkgs.findutils
      pkgs.procps
      # For ending a session started by --attach: the launcher asks whichever
      # compositor started it to quit. `niri msg` finds its own socket, but it
      # still has to be on PATH, and sway needs its client, which is not a
      # top-level attribute in nixpkgs.
      pkgs.niri
      pkgs.sway
      xwaylandSatellite
    ]
    ++ distroboxTools
  );

  # Read lazily, so the fact that virtualisation.podman.enable is set in
  # nixos.ifEnabled below does not matter here.
  podmanPackage = config.virtualisation.podman.package or pkgs.podman;

  xwaylandSatellite =
    inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.xwayland-satellite-unstable;

  kioskConfig = pkgs.writeText "guest-box-niri.kdl" (builtins.readFile ./kiosk.kdl);

  # The system-wide niri config. niri reads /etc/niri/config.kdl when the user
  # has no ~/.config/niri/config.kdl (the guest never does; nithin gets his from
  # home-manager), so the greeter's plain "Niri" entry -- which runs niri
  # directly and never goes through the guest's login shell -- starts the box
  # too, instead of presenting a plain desktop.
  niriConfig = pkgs.writeText "niri-guest-box.kdl" ''
    ${kioskConfig}

    spawn-at-startup ${sessionScript}/bin/guest-box-session --attach
  '';

  swayConfig = pkgs.writeText "sway-guest-box.config" (
    builtins.replaceStrings [ "@sessionScript@" ] [ "${sessionScript}" ] (
      builtins.readFile ./sway-config
    )
  );

  # Installed into the box by its init hook. They only ever talk to the host's
  # D-Bus daemons, where polkit decides.
  #
  # One derivation per file rather than a runCommand that heredocs them all out,
  # for two reasons. Nix strips the *common* leading indentation of a '' string,
  # so a single line indented less than the rest silently moves every heredoc
  # terminator and swallows the rest of the script into the first file -- a
  # broken package with no error anywhere. And symlinkJoin is not an option:
  # writeShellScript and writeTextFile each produce a *file*, and lndir only
  # merges directories, so a join of them comes out empty.
  hostExecStub = pkgs.writeShellScript "host-exec-stub" ''
    # Stands in for distrobox-host-exec and host-spawn. Says why, because
    # "command not found" would look like a broken install to a guest.
    echo "Running commands on the host is not available in this session." >&2
    exit 126
  '';

  # Power off the host. loginctl reaches the host's logind over the D-Bus system
  # bus shared with this container; polkit allows
  # org.freedesktop.login1.power-off for an active local session, so no password
  # is asked. The box itself cannot run host commands.
  guestShutdown = pkgs.writeShellScript "guest-shutdown" "loginctl poweroff";

  guestReboot = pkgs.writeShellScript "guest-reboot" "loginctl reboot";

  # bash, not the sh writeShellScript uses: the dialog branch below needs arrays
  # and mapfile.
  guestWifi = pkgs.writeTextFile {
    name = "guest-wifi";
    executable = true;
    text = ''
      #!/bin/bash
      # Join a wireless network. NetworkManager only runs on the host, so this
      # is nmcli over the shared system bus. The guest's polkit rule (see
      # modules/services/guest-box) allows scanning and saving their own
      # connection; it does not allow reading the owner's.
      set -u
      if [ "$#" -gt 0 ] && [ "$1" != "-l" ]; then
        exec nmcli device wifi connect "$1" ''${2+"$2"}
      fi

      list=$(nmcli -t -f SSID,SIGNAL,SECURITY device wifi list 2>/dev/null |
        awk -F: 'length($1) && $1 !~ /^\[/ {print $1 "|" $2 "|" $3}' |
        sort -t'|' -k2 -rn | awk '!seen[$1]++')
      [ -n "$list" ] || { echo "No wireless networks found."; exit 1; }

      if command -v dialog >/dev/null 2>&1; then
        mapfile -t ssids < <(printf '%s\n' "$list" | cut -d'|' -f1)
        mapfile -t rows < <(printf '%s\n' "$list" | awk -F'|' '{print $1 "  (" $2 "%)  " $3}')
        args=()
        for i in "''${!ssids[@]}"; do args+=("$i" "''${rows[$i]}"); done
        picked=$(dialog --menu "Connect to Wi-Fi" 22 64 14 "''${args[@]}" 3>&1 >/dev/tty)
        [ -n "$picked" ] || exit 0
      else
        printf '%s\n' "$list" | awk -F'|' '{print NR ") " $1 "  (" $2 "%)  " $3}'
        printf 'Network number: '
        read -r n
        picked=$(printf '%s\n' "$list" | sed -n "''${n}p" | cut -d'|' -f1)
        [ -n "$picked" ] || exit 1
      fi

      if nmcli -t -f SSID,ACTIVE device wifi list |
        awk -F: -v s="$picked" '$1 == s && $2 == "*" {found=1} END {exit !found}'; then
        echo "Already connected to $picked."
        exit 0
      fi

      open=$(nmcli -t -f SSID,SECURITY device wifi list |
        awk -F: -v s="$picked" '$1 == s {print $2; exit}')
      if [ -z "$open" ]; then
        echo "Open network, connecting to $picked"
        exec nmcli device wifi connect "$picked"
      fi

      exec nmcli --ask device wifi connect "$picked"
    '';
  };

  guestBoxTools = pkgs.runCommand "guest-box-tools" { } ''
    mkdir -p "$out/bin"
    ln -s ${hostExecStub} "$out/bin/host-exec-stub"
    ln -s ${guestShutdown} "$out/bin/guest-shutdown"
    ln -s ${guestReboot} "$out/bin/guest-reboot"
    ln -s ${guestWifi} "$out/bin/guest-wifi"
  '';

  # Runs as the box's root on every container start. --init-hooks is the *last*
  # step of `distrobox create`, so a failure here fails the whole creation --
  # including the desktop packages, which are already installed by then.
  # `set -eu` is therefore wrong: every optional step below says so itself and
  # carries on, and a missing browser must not cost the guest their desktop.
  #
  # Every line of this body must keep the same indentation. Nix strips the
  # *common* leading whitespace of a '' string, so de-indenting a single line
  # moves the heredoc terminators and swallows the rest of the script into the
  # first heredoc -- silently, with no build error.
  boxInitHook = pkgs.writeShellScript "guest-box-init-hook" ''
    set -eu

    # No host command execution from inside the box.
    #
    # distrobox bind-mounts its own host-exec helper over /usr/bin/distrobox-host-exec
    # and symlinks xdg-open and flatpak at it, which together give the box
    # "run this on my host as me" for free. That is the one hole worth closing,
    # and it cannot be closed by editing the file: the mount is a read-only bind
    # of a store path, so writing to it fails and unlinking it fails with "Device
    # or resource busy".
    #
    # So the helpers are shadowed earlier in PATH instead, from /usr/local/bin,
    # which every shell and every X session here searches first. The stub exits
    # 126 ("command found but not executable"), which is the conventional answer
    # for "this is deliberately not available" and fails loudly rather than
    # silently doing nothing.
    #
    # Shadowing, not removing: /usr/bin/flatpak and /usr/local/bin/xdg-open are
    # still live host-exec entry points on this image. They are not deleted
    # because they are symlinks *into* the read-only image layer and cannot be
    # either, and they are harmless as long as nothing looks them up first --
    # the box's PATH puts /usr/local/bin ahead of /usr/bin, and the real xdg-open
    # is installed into /usr/local/bin below so it wins regardless.
    install -D -m 0755 ${guestBoxTools}/bin/host-exec-stub /usr/local/bin/host-spawn
    install -D -m 0755 ${guestBoxTools}/bin/host-exec-stub /usr/local/bin/distrobox-host-exec

    # The box's own xdg-open, shadowing the symlink to host-exec. Also the one
    # XdgOpen desktop file the guest sees, so a link opens in the guest's browser
    # rather than on the host.
    rm -f /usr/local/bin/xdg-open
    cat >/usr/local/bin/xdg-open <<'XDG'
    #!/bin/sh
    exec sensible-browser "$@"
    XDG
    chmod 0755 /usr/local/bin/xdg-open
    # Plain ubuntu has no /usr/local/share/applications: the toolbx images do,
    # which is the kind of thing that only shows up on the image you do not
    # develop against.
    install -d -m 0755 /usr/local/share/applications
    cat >/usr/local/share/applications/xdg-open.desktop <<'XDG'
    [Desktop Entry]
    Name=Default browser
    Exec=sensible-browser %u
    Terminal=false
    Type=Application
    MimeType=x-scheme-handler/http;x-scheme-handler/https;
    XDG

    # No marco, MATE's window manager, and that is deliberate. Under niri the
    # Wayland compositor *is* the window manager for X clients: xwayland-satellite
    # owns the WM selection and forwards management to niri, so a second window
    # manager can never run -- marco starts, sees "already has a window manager",
    # spins and dies. An autostart entry for it was tried and produces exactly
    # that: a 100%-CPU zombie and log spam, no decorations. GTK apps draw their
    # own (pluma's header bars need no WM) and niri frames and focuses the rest.
    #
    # Remove the entry an earlier version of this hook wrote: boxes created
    # while it existed still carry it, and it would still start its zombie.
    rm -f /etc/xdg/autostart/marco.desktop /usr/share/mate/autostart/marco.desktop
    #

    # Guest helpers, driven by desktop icons on the MATE desktop.
    install -D -m 0755 ${guestBoxTools}/bin/guest-shutdown /usr/local/bin/guest-shutdown
    install -D -m 0755 ${guestBoxTools}/bin/guest-reboot /usr/local/bin/guest-reboot
    install -D -m 0755 ${guestBoxTools}/bin/guest-wifi /usr/local/bin/guest-wifi

    # The browser, from Google's own .deb.
    #
    # Not an apt repository: that needs a signing key inside the box, and a
    # key that fails would take the whole desktop install down with it. Not a
    # snap either -- snapd cannot run in a container, and Ubuntu's firefox and
    # chromium-browser packages are both snap stubs. A plain .deb is the only
    # thing that works here, and wget is in the package list, so it is always
    # present by the time this hook runs.
    #
    # Best effort on purpose: no browser is an inconvenience, a failed
    # creation is a dead kiosk.
    if ! command -v google-chrome-stable >/dev/null 2>&1; then
      if wget -q -O /tmp/chrome.deb \
        https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb &&
        apt-get install -y /tmp/chrome.deb; then
        :
      else
        echo "guest-box: could not install the browser" >&2
      fi
    fi
    rm -f /tmp/chrome.deb || true

    desktop="${boxCfg.boxHome}/Desktop"
    mkdir -p "$desktop"

    write_icon() {
      cat >"$desktop/$1.desktop" <<DESKTOP
    [Desktop Entry]
    Type=Application
    Name=$2
    Comment=$3
    Icon=$4
    Exec=$5
    Terminal=false
    DESKTOP
      chmod 0755 "$desktop/$1.desktop"
    }

    write_icon guest-shutdown "Shut down" "Power off this laptop" system-shutdown guest-shutdown
    write_icon guest-reboot "Restart" "Reboot this laptop" system-reboot guest-reboot
    write_icon guest-wifi "Connect to Wi-Fi" "Join a wireless network" network-wireless guest-wifi

    # The browser is the reason the box exists, so it gets an icon too -- but
    # only if the .deb install above actually worked.
    if command -v google-chrome-stable >/dev/null 2>&1; then
      write_icon guest-browser "Web browser" "Browse the web" google-chrome google-chrome-stable
    fi

    # The icons have to belong to the guest. This hook runs as the box's root,
    # so everything it writes is root-owned -- and the launcher wipes the box's
    # HOME as the guest on every login, which cannot remove root-owned files.
    # Reference the box HOME itself: the launcher creates it, so it already has
    # exactly the ownership the icons need. Last, after every icon is written.
    chown -R --reference="$desktop/.." "$desktop" || true
  '';

  # Creates the container on first use, wipes the box's HOME, and runs the MATE
  # session in it. Takes the X display to use as $1.
  boxLauncher = pkgs.writeShellApplication {
    name = "guest-box-launch";
    # The whole tool set comes from sessionPath below. A runtimeInputs list here
    # would be *prepended* to it by writeShellApplication, so a pkgs.podman in
    # this list would shadow the NixOS-configured one and rootless podman would
    # stop finding newuidmap.
    runtimeInputs = [ ];
    text = ''
      # See sessionScript: no errexit, so a failing box still ends the session.
      set +e +u +o pipefail

      export PATH=${sessionPath}
      DISPLAY="''${1:?usage: guest-box-launch <display>}"
      export DISPLAY
      log=${logFile}
      name=${boxCfg.name}
      home=${boxCfg.boxHome}

      # Never leak the host's SHELL into the box. Login sets SHELL to this very
      # session script, and distrobox-init reads $SHELL to pick the shell it
      # installs and resolves inside the box: basename gives "guest-box-session",
      # `apt-get install guest-box-session` fails, and on every start after the
      # first -- where the install fallback that saves creation does not run --
      # `SHELL=$(command -v guest-box-session)` fails under set -e and the whole
      # container refuses to start. /bin/bash names a shell that exists in every
      # box this module builds.
      export SHELL=/bin/bash

      # Progress goes to the log *and* to the console. Until niri is up, the
      # console *is* the screen, and a black screen with nothing to read is the
      # one failure a kiosk cannot explain to anyone; niri wipes the messages
      # once it takes the VT, which is exactly when they stop being useful.
      say() {
        line="$(printf '%s guest-box-launch %s' "$(date -Is)" "$*")"
        printf '%s\n' "$line" >>"$log" 2>/dev/null || :
        printf '%s\n' "$line" >&2 2>/dev/null || :
      }
      notify() { command -v notify-send >/dev/null 2>&1 && notify-send "Guest desktop" "$1" >/dev/null 2>&1 || :; }

      say "launch display=$DISPLAY name=$name"

      # Changing the image option has to actually change the box, or the option
      # is a lie. Compare what the container was created from against what is
      # configured now and rebuild when they differ. Nothing is lost: the box's
      # HOME is wiped on every login anyway, and the only thing kept across a
      # rebuild is the installed desktop, which gets installed again.
      current_image=$(podman inspect --format '{{.ImageName}}' "$name" 2>/dev/null)
      if [ -n "$current_image" ] && [ "$current_image" != "${boxCfg.image}" ]; then
        say "image changed ($current_image -> ${boxCfg.image}), rebuilding the box"
        distrobox rm --force "$name" >>"$log" 2>&1 || :
      fi

      # The init hook and the package list bake in at creation: distrobox runs
      # the stored hook on every start, so editing either in the module silently
      # does nothing to an existing box. Stamp both into container labels at
      # creation (the hook's store basename changes with its content; the
      # packages are hashed) and rebuild when the stamp no longer matches.
      # Same deal as the image: the installed desktop is the only casualty, and
      # it gets installed again.
      #
      # Labels rather than comparing hook output: there is no supported way to
      # patch a stored hook or a stored environment, and re-running the current
      # hook over an old box would half-apply it anyway.
      hook_id=${baseNameOf boxInitHook}
      packages_id=${
        builtins.substring 0 12 (builtins.hashString "sha256" (lib.concatStringsSep " " boxCfg.packages))
      }
      if podman container exists "$name" 2>/dev/null; then
        current_hook=$(podman inspect --format '{{index .Config.Labels "guest-box.init-hook"}}' "$name" 2>/dev/null)
        current_packages=$(podman inspect --format '{{index .Config.Labels "guest-box.packages"}}' "$name" 2>/dev/null)
        if [ "$current_hook" != "$hook_id" ] || [ "$current_packages" != "$packages_id" ]; then
          say "box configuration changed (hook $current_hook -> $hook_id, packages $current_packages -> $packages_id), rebuilding the box"
          distrobox rm --force "$name" >>"$log" 2>&1 || :
        fi
      fi

      # Boxes created before the SHELL export above carry the session script as
      # their SHELL, baked into the container's stored environment, and
      # distrobox-init reads exactly that on every start: `SHELL=$(command -v
      # ...)` fails under set -e and the container exits 1, forever, on every
      # login after the first. There is no supported way to patch a stored env,
      # so a poisoned box is rebuilt once.
      #
      # The match is deliberately narrow: a stored SHELL that names our session
      # script (or any /nix/store path, which can never resolve inside an
      # Ubuntu box). Matching on exact healthy values would be backwards --
      # "bash" and "/bin/bash" are both fine, and the check must not rebuild a
      # healthy box on every login.
      if podman container exists "$name" 2>/dev/null; then
        stored_shell=$(podman inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$name" 2>/dev/null | sed -n 's/^SHELL=//p' | head -1)
        case "$stored_shell" in
          *guest-box-session* | /nix/store/*)
            say "box carries a poisoned SHELL ($stored_shell), rebuilding once"
            distrobox rm --force "$name" >>"$log" 2>&1 || :
            ;;
        esac
      fi

      if ! podman container exists "$name" 2>/dev/null; then
        notify "Preparing the guest desktop. First run only, this can take a while."
        say "creating container $name from ${boxCfg.image}"
        say "this pulls the image and installs the desktop; it takes a few minutes"
        if ! distrobox create \
          --name "$name" \
          --image "${boxCfg.image}" \
          --home "$home" \
          --yes \
          --volume /run/dbus/system_bus_socket:/run/dbus/system_bus_socket \
          --additional-packages "${lib.concatStringsSep " " boxCfg.packages}" \
          --init-hooks ${lib.escapeShellArg boxInitHook} \
          --additional-flags "--label guest-box.init-hook=$hook_id --label guest-box.packages=$packages_id" \
          >>"$log" 2>&1; then
          say "distrobox create failed"
          notify "The guest desktop could not be created. Ask the owner for the log."
          exit 1
        fi
        say "container created"
      fi

      # "Wipe the guest's data" happens here: the box's HOME is on the ephemeral
      # root and is recreated from scratch on every login.
      rm -rf -- "$home"
      mkdir -p -- "$home"

      # MATE needs its own session bus (mate-session expects to own it); audio
      # and the X11 display still come from the host session.
      distrobox enter "$name" -- dbus-run-session -- mate-session >>"$log" 2>&1
      say "box exited with $?"

      # If a compositor started us, the session is *its* lifecycle, and the box
      # ending has to take it down with it -- otherwise the guest would be left
      # staring at an empty desktop with no way out. WAYLAND_DISPLAY is what
      # tells the two cases apart: niri and sway both export it to the
      # processes they spawn, and neither exports it to the process that started
      # them. In the login-shell case the parent session script is watching this
      # process and ends the session itself.
      if [ -n "''${WAYLAND_DISPLAY:-}" ]; then
        say "box ended under $WAYLAND_DISPLAY; asking the compositor to quit"
        niri msg action quit >/dev/null 2>&1 || swaymsg exit >/dev/null 2>&1 || :
      fi
    '';
  };

  # The guest's entire session, in two modes:
  #   (default)  login shell and greeter Exec: start Xwayland and the box, run
  #              niri in the foreground, tear everything down when it exits.
  #   --attach  used from the system-wide niri and sway fallback configs: start
  #              Xwayland and the box, then return, so the compositor that is
  #              already running displays them.
  sessionScript = pkgs.writeShellApplication {
    name = "guest-box-session";
    # See boxLauncher: sessionPath is the whole tool set, and anything listed
    # here would be prepended to it.
    runtimeInputs = [ ];
    text = ''
      # writeShellApplication turns on errexit/nounset/pipefail; a session
      # script wants the opposite -- every step that can fail has a fallback,
      # and a failing `distrobox enter` must still reach the session teardown.
      set +e +u +o pipefail

      export PATH=${sessionPath}
      log=${logFile}
      attach=0
      [ "''${1:-}" = "--attach" ] && attach=1

      # See boxLauncher: the log for the owner, the console for whoever is
      # looking at the screen right now.
      say() {
        line="$(printf '%s guest-box-session %s' "$(date -Is)" "$*")"
        printf '%s\n' "$line" >>"$log" 2>/dev/null || :
        printf '%s\n' "$line" >&2 2>/dev/null || :
      }
      notify() { command -v notify-send >/dev/null 2>&1 && notify-send "Guest desktop" "$1" >/dev/null 2>&1 || :; }

      say "start uid=$(id -u) tty=''${XDG_VTNR:-?} seat=''${XDG_SEAT:-?} attach=$attach"
      mkdir -p "$(dirname "$log")" 2>/dev/null || :

      # The X display belongs to the compositor, not to us: niri binds an X11
      # socket and a /tmp/.X<n>-lock holding *niri's own pid* when it starts,
      # and only then spawns xwayland-satellite -- when the first X client
      # connects. So the socket is there before the X server is, and a client
      # that connects early simply waits in the listen backlog.
      #
      # Reading the pid out of the lock file is what keeps the guest off the
      # owner's screen: if the owner is logged in, their niri holds :0 and
      # this session's niri takes the next free number.
      display_of_pid() {
        local lock pid n
        for lock in /tmp/.X*-lock; do
          [ -e "$lock" ] || continue
          pid="$(tr -d '[:space:]' <"$lock" 2>/dev/null)"
          [ "$pid" = "$1" ] || continue
          n="''${lock#/tmp/.X}"
          printf ':%s' "''${n%-lock}"
          return 0
        done
        return 1
      }

      box_pid=""
      niri_pid=""

      if [ "$attach" -eq 1 ]; then
        # Started by a compositor from its own config, so it has already handed
        # us the X display it serves X11 clients on. --attach only ever runs in
        # the guest's own session (the system-wide niri and sway configs), so
        # quitting niri when the box ends ends that session, which is the point.
        display="''${DISPLAY:-}"
        if [ -z "$display" ]; then
          say "attach mode: the compositor exported no DISPLAY"
          notify "Could not start the guest desktop."
          exit 1
        fi
        say "attach mode: DISPLAY=$display from the running compositor"
        ${boxLauncher}/bin/guest-box-launch "$display" &
        exit 0
      fi

      cleanup() {
        trap - EXIT INT TERM
        for pid in "$box_pid" "$niri_pid"; do
          [ -n "$pid" ] && kill "$pid" 2>/dev/null || :
        done
        wait 2>/dev/null || :
        # --yes matters: without it distrobox stop prompts "[Y/n]", and there
        # is no tty here to answer -- the container would survive the session
        # and the next login would enter a stale box (no init hook re-run, so
        # no desktop icons after the wipe). Belt and braces with podman itself:
        # a lingering box is a lingering guest session in another skin.
        distrobox stop --yes ${boxCfg.name} >/dev/null 2>&1 || \
          podman stop -t 10 ${boxCfg.name} >/dev/null 2>&1 || :
        say "cleanup done"
      }
      trap cleanup EXIT INT TERM

      # niri first: it is what serves X11 to the box, and it cannot be told
      # which display to use -- it picks the first free one.
      ${pkgs.niri}/bin/niri --config ${kioskConfig} &
      niri_pid=$!

      display=""
      for _ in $(seq 1 150); do
        display="$(display_of_pid "$niri_pid")" && break
        kill -0 "$niri_pid" 2>/dev/null || break
        sleep 0.1
      done
      if [ -z "$display" ]; then
        say "niri (pid $niri_pid) never took an X display"
        notify "Could not start the guest desktop."
        exit 1
      fi
      export DISPLAY="$display"
      say "using DISPLAY=$DISPLAY from niri pid $niri_pid"

      # dex fixes X11 keyboard handling (dead keys, compose) for the MATE apps,
      # which speak X11 to this Xwayland.
      ${pkgs.dex}/bin/dex -a -u Firefox >/dev/null 2>&1 || :

      notify "Starting the guest desktop…"
      ${boxLauncher}/bin/guest-box-launch "$DISPLAY" &
      box_pid=$!

      # The session ends when the desktop does. That is the logout path (the
      # guest closing MATE), and it is also the only way out if the box died --
      # the session must not sit there on an empty screen forever.
      #
      # Waiting on *both* is also what makes this mode's teardown work: the trap
      # below kills whichever one is still running. Asking niri to quit through
      # `niri msg` would be the tidier way to end it, and it is not available
      # here: niri exports WAYLAND_DISPLAY only to processes it spawns, and this
      # script is niri's parent, so `niri msg` has no socket to talk to. SIGTERM
      # is how a session ends anyway.
      wait -n "$box_pid" "$niri_pid"
      say "niri or the box exited; ending the session"
    '';
  };

  # The session package is the only way into the greeter's session list: the
  # greeter runs with XDG_DATA_DIRS=sessionData.desktops/share and nothing else.
  sessionPackage = pkgs.runCommand "guest-mate-session" { providedSessions = [ "guest-mate" ]; } ''
    mkdir -p "$out/share/wayland-sessions"
    cat >"$out/share/wayland-sessions/guest-mate.desktop" <<'DESKTOP'
    [Desktop Entry]
    Name=Distrobox (Ubuntu MATE)
    Comment=Ubuntu MATE desktop in a container (guest)
    Exec=${sessionScript}/bin/guest-box-session
    Type=Application
    DesktopNames=MATE
    DESKTOP
  '';
in
delib.module {
  name = "services.guest-box";

  options = delib.singleEnableOption true;

  # Unconditional: the file-level bindings above read these.
  nixos.always = {
    options.services.guest-box = {
      user = lib.mkOption {
        type = lib.types.str;
        default = "guest";
        description = "The account whose whole session is the box.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "ubuntu-mate";
        description = "distrobox container name for the guest desktop.";
      };

      image = lib.mkOption {
        type = lib.types.str;
        default = "docker.io/library/ubuntu:24.04";
        description = ''
          OCI image for the box. Pin a digest here to make the guest desktop
          byte-identical across rebuilds; the tag is rebuilt upstream regularly.

          Plain Ubuntu rather than a toolbx image, and that is a measured
          decision rather than a preference. The toolbx images (the public quay
          namespace is just ubuntu-toolbox and arch-toolbox) ship a CLI
          development toolchain: ubuntu-toolbox:24.04 is 196 MB compressed, 378
          packages, and not one desktop environment or browser among them. Plain
          ubuntu:24.04 is 29 MB of the same userland. The registries that do
          publish a ready-made desktop -- linuxserver/webtop:ubuntu-mate, 1.4 GB,
          MATE and Firefox included -- run their own Xvfb and window manager to
          be *served to a browser*, so their desktop never reaches our Xwayland
          and the laptop screen stays black.
        '';
      };

      boxHome = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/guest-box/home";
        description = ''
          Home directory inside the container. It lives on the ephemeral root
          on purpose: the launcher recreates it on every login, so it is where
          "wipe the guest's data" happens.
        '';
      };

      packages = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          # The MATE desktop, minus the metapackage. The full
          # mate-desktop-environment is 490 MB and 716 packages -- user guides,
          # translations, extra applets and a screensaver a kiosk has no use
          # for. This is its real dependency set plus the four apps a guest can
          # actually use, which measures 307 MB.
          #
          # Naming notes for noble, all of them learned the hard way:
          # ubuntu-mate-desktop-minimal does not exist in noble at all, and
          # /usr/bin/mate-session -- the binary the launcher runs -- ships in
          # mate-session-manager, which is a hard Depends of the -core package.
          # mate-desktop is just the About and Colour Settings dialogs.
          "mate-desktop-environment-core"
          "mate-themes"
          "mate-backgrounds"
          "mate-terminal"
          "pluma"
          "atril"
          "fonts-liberation"
          "xdg-utils"
          "dbus"
          # loginctl (power control) and nmcli (wifi) talk to the host's
          # daemons over the shared system bus; no daemon runs in here.
          "systemd"
          "network-manager"
          "policykit-1"
          # wget is here because the init hook uses it to fetch the browser.
          "wget"
          "ca-certificates"
          "sudo"
        ];
        description = "Packages distrobox installs into the box on creation.";
      };
    };
  };

  # denix wraps this body in mkIf, so it has to be a plain attribute set;
  # config/lib/pkgs come from the file header, and every derived script from the
  # let above.
  nixos.ifEnabled =
    { ... }:
    {
      # Rootless podman. The NixOS module puts /run/wrappers on podman's PATH,
      # where security.shadow provides newuidmap/newgidmap with
      # cap_setuid/cap_setgid, so the guest gets its whole subuid range
      # (/etc/subuid is auto-allocated for normal users) and podman can unpack
      # image layers that own arbitrary uids.
      #
      # security.shadow is what puts those wrappers there, and nothing else in
      # a guest's configuration can be relied on to enable it.
      security.shadow.enable = true;
      virtualisation.podman.enable = true;

      # graphroot ends up under /persist, i.e. btrfs. Native overlayfs cannot
      # use btrfs as its upper layer (it needs trusted.* xattrs) and podman's
      # automatic btrfs graph driver is unreliable for a plain directory that is
      # not a subvolume, so pin overlay + fuse-overlayfs.
      virtualisation.containers = {
        enable = true;
        containersConf.settings.storage = {
          driver = "overlay";
        };
        containersConf.settings.storage.options.overlay = {
          mount_program = "${lib.getBin pkgs.fuse-overlayfs}/bin/fuse-overlayfs";
        };
      };

      # Login shell: getty on a TTY and `su - guest` both land in the box, so
      # the guest has no shell to drop into. A store path rather than a
      # derivation because users.users.<name>.shell is typed as a path, and
      # sessionScript is kept in the closure by environment.systemPackages below.
      users.users.${guestUser}.shell = lib.mkForce "${sessionScript}/bin/guest-box-session";

      services.displayManager.sessionPackages = [ sessionPackage ];

      # System-wide fallbacks for niri and sway, so a guest picking the greeter's
      # plain "Niri" or "Sway" entry still ends up in the box.
      environment.etc."niri/config.kdl".source = niriConfig;
      environment.etc."sway/config".source = swayConfig;

      # sessionScript is referenced as a bare path from /etc/passwd, so it has to
      # be a closure root, not just a string in a config file.
      environment.systemPackages = [
        sessionScript
        pkgs.dex
      ];

      # The box's own HOME and the session log live on the wiped root; only the
      # container's filesystem (in /persist/home/guest) survives a boot.
      systemd.tmpfiles.settings."guest-box" = {
        "/var/lib/guest-box".d = {
          user = guestUser;
          group = "users";
          mode = "0755";
        };
        "/var/lib/guest-box/home".d = {
          user = guestUser;
          group = "users";
          mode = "0700";
        };
        "/var/log/guest-box".d = {
          user = guestUser;
          group = "users";
          mode = "0755";
        };
      };

      # The guest is a kiosk account: its only privileged capabilities are the
      # desktop power actions, joining a wireless network, and plugging in
      # removable media. Two shipped defaults are too wide for that:
      #   * NixOS grants the `networkmanager` group a blanket yes over every
      #     org.freedesktop.NetworkManager.* action, which includes
      #     settings.modify.system -- i.e. reading the owner's stored Wi-Fi
      #     passwords out of the root-only /etc/NetworkManager.
      #   * udisks2 ships filesystem-mount and loop-setup as allow_active:yes, so
      #     any local session user can ask it to mount a block device.
      # Numbered to be read *before* 10-nixos.rules; polkit takes the first
      # rule that has an opinion.
      environment.etc."polkit-1/rules.d/05-nixos-guest.rules".text = ''
        polkit.addRule(function (action, subject) {
          if (subject.user != "${guestUser}") {
            return;
          }
          var allow = [
            "org.freedesktop.login1.can-power-off",
            "org.freedesktop.login1.can-reboot",
            "org.freedesktop.login1.power-off",
            "org.freedesktop.login1.reboot",
            "org.freedesktop.login1.inhibit-block-idle",
            "org.freedesktop.login1.inhibit-block-shutdown",
            "org.freedesktop.login1.inhibit-block-sleep",
            "org.freedesktop.login1.inhibit-delay-idle",
            "org.freedesktop.login1.inhibit-delay-shutdown",
            "org.freedesktop.login1.inhibit-delay-sleep",
            "org.freedesktop.NetworkManager.network-control",
            "org.freedesktop.NetworkManager.wifi.scan",
            "org.freedesktop.NetworkManager.settings.modify.own",
            "org.freedesktop.udisks2.filesystem-mount",
            "org.freedesktop.udisks2.eject-media",
            "org.freedesktop.udisks2.drive-eject",
            "org.freedesktop.udisks2.drive-detach"
          ];
          if (allow.indexOf(action.id) >= 0) {
            return polkit.Result.YES;
          }
          var deny = [
            "org.freedesktop.udisks2.",
            "org.freedesktop.block.",
            "org.freedesktop.Flatpak.",
            "org.freedesktop.packagekit.",
            "org.freedesktop.fwupd.",
            "org.freedesktop.NetworkManager."
          ];
          for (var i = 0; i < deny.length; i++) {
            if (action.id.indexOf(deny[i]) == 0) {
              return polkit.Result.NO;
            }
          }
        });
      '';
    };
}
