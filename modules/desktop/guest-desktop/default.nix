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

  # Resolve the logind session id of the session we are running in, from our own
  # cgroup. greetd never sets XDG_SESSION_ID -- `strings` on greetd 0.10.3 yields
  # exactly XDG_SEAT, XDG_SESSION_CLASS and XDG_VTNR, and it forwards the PAM
  # environment verbatim -- so the variable mutter needs is simply absent, and
  # gnome-shell dies with "Failed to find any matching session".
  #
  # We cannot ask systemd properly without libsystemd, and we do not need to:
  # logind names every session's scope `session-<id>.scope`, and greetd runs the
  # session command as a direct child of the session leader, so our own cgroup
  # *is* the session scope. Verified: greetd's leader for session 15 sat in
  # /user.slice/user-1000.slice/session-15.scope, matching /run/systemd/sessions/15.
  #
  # Deliberately host-side. Inside the box this cannot work: podman gives
  # containers a private cgroup namespace, so /proc/self/cgroup there reads "/"
  # and the processes sit in a libpod-*.scope rather than any session scope.
  sessionIdScript = pkgs.writeShellApplication {
    name = "guest-desktop-session-id";
    # Not lib.getBin alone: on a derivation with no `bin` output attribute that
    # yields the whole output *directory*, and the caller would execute a
    # directory and greetd would flash "Is a directory". Hence /bin/<name> at
    # the call site, exactly as distrobox and niri are invoked below.
    #
    # Every bare tool below must come from here. The greeter session PATH is
    # inherited unchanged (`export PATH="$PATH"` in the wrapper), and on NixOS
    # /usr/bin is nearly empty -- a missing grep/awk/sleep dies with "command
    # not found" under errexit, mid-login, with only the VT to show it.
    # podman and distrobox stay absolute store paths (never inputs): prepending
    # must not shadow the system podman, which is the one that knows newuidmap.
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gnugrep
      gawk
    ];
    text = ''
      cgroup=""
      if [ -r /proc/self/cgroup ]; then
        cgroup="$(awk -F: '$1 == "0" { print $3; exit }' /proc/self/cgroup)"
      fi

      # grep -oE rather than a sed substitution or a bash regex. The obvious sed
      # spelling uses backslash-pipe for alternation, which silently degrades to
      # an escaped literal if you happened to pick pipe as the s delimiter and
      # then matches nothing at all; and the obvious bash-regex follow-up needs
      # an array subscript, which cannot be written here at all because Nix
      # interpolates a dollar-brace inside an indented string as an attribute
      # lookup and fails to evaluate. Requiring digits after the hyphen also
      # keeps "session.slice" (a systemd slice, not a session) from matching.
      #
      # The "|| true" is load-bearing: writeShellApplication runs this with
      # errexit and pipefail, so a no-match grep would abort the script right
      # here and the diagnostic below -- the one that says what actually went
      # wrong -- would never be printed. It would just exit 1 silently.
      id="$(printf '%s' "$cgroup" | grep -oE 'session-[0-9]+' | head -n 1 | cut -d- -f2 || true)"

      if [ -z "$id" ]; then
        printf 'guest-desktop-session-id: no session scope in cgroup "%s".\n' "$cgroup" >&2
        printf 'The guest desktop needs a real logind session; a TTY or SSH login\n' >&2
        printf 'has no session scope, so this is not the greeter.\n' >&2
        exit 1
      fi

      # Only accept an id logind still considers active. A stale scope from a
      # finished session would hand mutter a dead session, which fails the same
      # way as no session at all but much harder to read.
      if ! grep -qs '^STATE=active$' "/run/systemd/sessions/$id"; then
        printf 'guest-desktop-session-id: session %s is not active.\n' "$id" >&2
        exit 1
      fi

      printf '%s' "$id"
    '';
  };

  # The whole session entry, in one script, because the greeter only ever runs
  # one Exec and there is no per-user session concept to hook into.
  #
  # Every path is absolute. greetd does not run the session through a shell with
  # a login PATH: it builds `exec <argv joined by spaces>` and hands it to
  # /bin/sh -c, so anything resolved via PATH is at the mercy of whatever PATH
  # survived PAM.
  dispatcher = pkgs.writeShellApplication {
    name = "desktop-session";
    # Every bare tool below must come from here: same PATH inheritance trap
    # as sessionIdScript above. podman and distrobox stay absolute store
    # paths (never inputs) so nothing shadows the system podman.
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gnugrep
      gawk
    ];
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
          # Per-login transcript. Every failure so far died on the greeter's
          # screen, leaving post-mortem forensics (which store path ran? did
          # the loop pass? which manager owned the bus?) to guesswork. This
          # file answers all of that. One file per login in persisted storage;
          # files older than a week are cleaned at the start.
          session_log_dir="$HOME/.local/share/desktop-session"
          mkdir -p "$session_log_dir" 2>/dev/null || :
          find "$session_log_dir" -maxdepth 1 -name 'session-*.log' -mtime +7 -delete 2>/dev/null || :
          # The id is not known yet, so start unnamed and rename after the
          # resolver runs. If even that fails, the tmp file still says so.
          session_log="$session_log_dir/session-pending-$$.log"
          log() { printf '%s %s\n' "$(date '+%H:%M:%S')" "$*" >>"$session_log"; }
          log "dispatcher start, user=$(id -un)"
          # The one variable mutter cannot start without, resolved from our own
          # cgroup because greetd does not provide it (see sessionIdScript).
          # Without it gnome-session's units all come up and then
          # org.gnome.Shell@user.service fails with "Failed to find any matching
          # session", taking the whole session down with it.
          #
          # Resolved per login and never cached: it is a property of this
          # session, not of the user. In particular the box's user manager
          # environment is refreshed with the CURRENT id on every login (from
          # inside the session enter) and never trusted to carry yesterday's:
          # linger keeps that manager, and its environment, alive across
          # logouts, so a stale ID would leave everything pointing at a dead
          # session.
          #
          # First thing the branch does, before podman: it reads two files, so
          # it costs nothing, and it fails with the real reason ("this is not
          # the greeter") instead of burying a missing container in front of
          # it.
          if ! XDG_SESSION_ID="$(${lib.getBin sessionIdScript}/bin/guest-desktop-session-id 2>>"$session_log")"; then
            log "resolver failed"
            exit 1
          fi
          export XDG_SESSION_ID
          mv "$session_log" "$session_log_dir/session-$XDG_SESSION_ID.log" 2>/dev/null || :
          session_log="$session_log_dir/session-$XDG_SESSION_ID.log"
          log "session id $XDG_SESSION_ID"

          # Teardown, armed from here -- not just around the session command.
          # Everything below this point (waits, enters, kills) can die or be
          # killed, and without an armed trap a death there leaves no trace:
          # measured once, transcript ending mid-flight with no teardown line.
          # Every command in box_stop already swallows failure, so arming it
          # before anything has started is safe: stopping a never-started
          # target and unmounting a never-made bind are silent no-ops.
          box_stop() {
            log "teardown: stopping box session target"
            # One enter for the three user-manager steps: the stop, the removal
            # of the session-id drop-ins this login wrote (leaving them would
            # pin the next unit start to a session that is already gone --
            # linger keeps this manager alive across logouts), and the reload
            # that makes the removal take effect. Single quotes so $HOME is the
            # container's own view of the shared home.
            # shellcheck disable=SC2016
            ${lib.getBin pkgs.distrobox}/bin/distrobox enter --name ${cfg.containerName} -- \
              /bin/sh -c '
                systemctl --user stop gnome-session@gnome.target
                find "$HOME/.config/systemd/user" -maxdepth 2 -name 50-desktop-session.conf -delete
                systemctl --user daemon-reload
              ' >/dev/null 2>&1 || :
            # Release the host session file bound at login. Each login binds its
            # own id, so without this stale binds accumulate in the box across
            # logins. Harmless if the bind never happened (rebind failed, or the
            # container is gone): the || : swallows it, same as above.
            ${lib.getBin pkgs.distrobox}/bin/distrobox enter --name ${cfg.containerName} -- \
              sudo -n umount /run/systemd/sessions/"$XDG_SESSION_ID" >/dev/null 2>&1 || :
            # Remove the placeholder the rebind touched. After the unmount what
            # is left is an EMPTY file in the box's own session directory, and
            # sd_session_get_type/-state read those files directly: a stale
            # empty entry is not a session to them, but it does show up in
            # `ls` and in every "Couldn't get type" warning. If the unmount
            # above failed this unlink hits EBUSY on the mountpoint and does
            # nothing, which is the safe direction -- it can never reach the
            # host's copy through an active bind.
            ${lib.getBin pkgs.distrobox}/bin/distrobox enter --name ${cfg.containerName} -- \
              sudo -n rm -f /run/systemd/sessions/"$XDG_SESSION_ID" >/dev/null 2>&1 || :
            log "teardown done"
          }
          trap box_stop EXIT

          # Point the *session* -- and only the session -- at the host system
          # bus. The box keeps its own bus at the default path (its broker
          # serves its logind, PID 1, polkit and user manager; see
          # containerFlags for why sharing the socket broke all of that), while
          # everything gnome-session starts inherits this and talks to host
          # logind instead. GDBus honors the variable, and mutter is a GDBus
          # client, so TakeControl/TakeDevice resolve against the guest's real
          # host session. The socket is reached through distrobox's own
          # host-root mount, which survives the box's init where a create-time
          # bind under the box's /run did not.
          export DBUS_SYSTEM_BUS_ADDRESS="unix:path=/run/host/run/dbus/system_bus_socket"

          # Overrides the greeter's niri-derived values, which is the entire
          # reason the dispatcher exists rather than two session entries.
          # XDG_SESSION_TYPE stays what the greeter set (wayland, from the
          # wayland-sessions directory).
          export XDG_CURRENT_DESKTOP=GNOME
          export XDG_SESSION_DESKTOP=gnome

          # Refuse to start unless the container is already there.
          #
          # `distrobox enter` does NOT fail on a missing container: it offers to
          # create one and, with no terminal to ask (greetd gives the session no
          # usable stdin), `read` returns EOF, the default answer is taken, and
          # it creates the container from container_image_default --
          # registry.fedoraproject.org/fedora-toolbox:latest -- with none of the
          # flags in containerFlags: no systemd init, no dbus-daemon, no /dev/dri,
          # no host bus mount. That container cannot run GNOME at all; the
          # session dies seconds later on a missing /usr/bin/gnome-session, and
          # what is left behind is a 2 GB wrong container that the next login
          # happily reuses. This is the exact failure the one-time setup in
          # docs/guest-desktop.md exists to prevent, so the check is here, in
          # code, rather than left to the guest to remember.
          #
          # `podman container exists` rather than parsing distrobox output: it is
          # the same query the login hook uses, and it cannot be defeated by a
          # prompt we cannot see.
          if ! ${lib.getBin podmanPkg}/bin/podman container exists ${cfg.containerName}; then
            printf 'desktop-session: distrobox container %s does not exist.\n' \\
              ${cfg.containerName} >&2
            log "container missing, refusing"
            printf 'It is created once, by hand, as %s -- see docs/guest-desktop.md.\n' \\
              ${cfg.guestUser} >&2
            printf 'Refusing to start: distrobox would otherwise create one with no\n' >&2
            printf 'systemd init, no /dev/dri and no host bus, which cannot run GNOME.\n' >&2
            exit 1
          fi
          log "container present"

          # Put the host's session file where mutter looks for it.
          #
          # containerFlags mounts /run/systemd/sessions into the box, and it is
          # silently not there: the box runs systemd as init, so it has its own
          # /run/systemd and its own session, and that shadowed the bind mount.
          # Measured inside the box: `/run/systemd/sessions` was not a
          # mountpoint and held only the box's own `c1`, while the host's `1` and
          # `4` were visible through distrobox's own host-root mount. mutter
          # resolves XDG_SESSION_ID with sd_session_is_active, which reads
          # /run/systemd/sessions/<id> *directly* and never asks logind, so a
          # missing file there is fatal: sd_session_is_active surfaces it as the
          # `ENXIO` "No such device or address" failure, which reads as
          # "Failed to find any matching session". (The host bus is reached
          # separately, through DBUS_SYSTEM_BUS_ADDRESS above -- nothing here
          # is mounted from the host at create time anymore.)
          #
          # ONE FILE, never the whole directory, and this is not a detail.
          # Binding the directory replaces the box's own session bookkeeping
          # with the host's: the box's logind then finds no session of its own,
          # `pam_systemd` fails CreateSession with SystemError, user@guest.service
          # exits 1 without ever setting XDG_RUNTIME_DIR, and gnome-session
          # aborts with "No session bus running!" before it reaches mutter at
          # all. Observed on hardware: that is exactly the failure a whole-
          # directory bind produces. Both sets of files have to coexist, and only
          # the single file the guest's session needs is missing from the box.
          #
          # Rebinding from /run/host rather than adding another mount to
          # containerFlags is deliberate: it needs no container recreation (the
          # flags are fixed at create time), /run/host is the host root that
          # every distrobox container has and that distrobox-host-exec itself
          # relies on, and it is verified to survive where the /run/systemd bind
          # did not.
          #
          # Kept on one line, with no continuation: a trailing backslash inside an
          # `if !` condition trips shellcheck rule SC2251, and this is not worth
          # fighting over formatting.
          printf 'desktop-session: preparing the box (first boot takes a minute).\n' >&2
          log "rebind start"
          if ! ${lib.getBin pkgs.distrobox}/bin/distrobox enter --name ${cfg.containerName} -- sudo -n /bin/sh -c "touch /run/systemd/sessions/$XDG_SESSION_ID && mount --bind /run/host/run/systemd/sessions/$XDG_SESSION_ID /run/systemd/sessions/$XDG_SESSION_ID"; then
            printf 'desktop-session: could not expose host session %s to the box.\\n' "$XDG_SESSION_ID" >&2
            log "rebind failed"
            printf 'mutter resolves XDG_SESSION_ID by reading /run/systemd/sessions/<id>\\n' >&2
            printf 'directly, so without this the session cannot start.\\n' >&2
            exit 1
          fi
          log "rebind ok"

          # Get the box user manager ready to receive the host session id,
          # which is written inside the session enter below (measured: a write
          # made HERE, before that enter, is overwritten by the enter's own PAM
          # session a moment later, and the units -- which inherit the manager
          # environment, not gnome-session's -- then start with the box's id).
          # Note that even that write is only half the channel: gnome-session
          # uploads XDG_SESSION_ID on its *unset* list when it exports the
          # activation environment (gsm-util.c variable_blacklist), so the
          # manager value is gone again before org.gnome.Shell@user.service
          # starts. The id therefore also goes in as a unit drop-in, from
          # inside the session enter. What MUST be in the manager environment
          # is DBUS_SYSTEM_BUS_ADDRESS: mutter builds its logind proxies on the
          # system bus, and only the host logind owns the host session.
          # gnome-session does not propagate XDG_SESSION_ID from its own
          # environment into the manager (measured: session binary, service and
          # manager all lack it while carrying every other forwarded variable),
          # so without the manager write the units start with no id at all --
          # and mutter, finding neither id nor host scope, falls back to the
          # box session, which can never become active, and parks forever with
          # no log line and no syscalls.
          #
          # This is deliberately NOT "never cache XDG_SESSION_ID in the box":
          # that rule bans a STALE id surviving across logins. The write inside
          # the session enter gives the box the current login's id immediately
          # before starting its session, so it cannot be stale -- and the EXIT
          # trap above stops the session on logout, so nothing outlives the id
          # it was given.
          #
          # The wait loop covers cold boot: on the first login ever, this very
          # session's enter may have just started the container, and the
          # linger-pinned manager takes a while to appear -- measured missing
          # at 30s on a fresh box boot, so the budget below is a full minute.
          # (The loop body itself was verified working by hand; only the
          # timing was wrong.)
          # Wait for the box user manager's bus BEFORE the first enter below.
          # Two facts make the ordering load-bearing:
          #
          # - Every `distrobox enter` opens a pam session in the box, and the
          #   first pam session starts a user manager if none is up yet. On a
          #   fresh box boot that races the linger-pinned manager, which is
          #   also starting: measured twice, two `systemd --user` processes a
          #   second apart, one bus between them. Whichever manager loses the
          #   bus leaves no trace, so the id has to be written to whichever
          #   manager actually owns the bus -- which is why the write lives
          #   inside an enter (it talks to the bus) rather than to a pid.
          # - `podman exec`, unlike enter, creates no pam session and triggers
          #   no manager start, so polling the bus socket through it cannot
          #   join -- or start -- the race. Once the socket exists, the manager
          #   is up, stable and sole, and every later pam session reuses it.
          #
          # If the bus never appears (linger somehow not in effect), proceed
          # anyway: the first enter's pam session then starts the only manager
          # and there is nothing to race with.
          box_uid="$(id -u)"
          # Separate declare and export: a combined
          # `export XDG_RUNTIME_DIR=...$(...)` masks the substitution's return
          # value and trips shellcheck SC2155, which fails the build.
          export XDG_RUNTIME_DIR="/run/user/$box_uid"
          # If the box is not running at all (fresh VM boot, recre­ated
          # container), skip the wait: there is no manager coming, and the
          # rebind enter below boots the box. The set-environment loop after
          # that covers the manager's appearance.
          if ! ${lib.getBin podmanPkg}/bin/podman container inspect --format '{{.State.Running}}' ${cfg.containerName} 2>/dev/null \
            | grep -qx true; then
            printf 'desktop-session: container not running; the login will start it.\n' >&2
          else
            tries=0
            while ! ${lib.getBin podmanPkg}/bin/podman exec --user 0 ${cfg.containerName} \
              test -S "/run/user/$box_uid/bus" >/dev/null 2>&1; do
              tries=$((tries + 1))
              if [ "$tries" -ge 12 ]; then
                printf 'desktop-session: no user bus in the box after %ss; ' "$((tries * 5))" >&2
                printf 'continuing, the first enter will start the manager.\n' >&2
                break
              fi
              sleep 5
            done
          fi
          # If the race already happened -- two `systemd --user` processes, one
          # bus -- converge it before touching anything: keep the manager that
          # owns the user bus (found by walking up from the user-scope
          # dbus-broker-launch), stop the others. A manager with no units yet
          # loses nothing, and the session has not started, so nothing depends
          # on either of them. Discovery and killing both go through
          # `podman exec`, which creates no pam session and therefore cannot
          # start yet another manager while looking.
          # A /proc walk, not `ps`: ps is not in the container image. Measured --
          # the command produced nothing at all, so the count below was always
          # 0, "box managers:" always logged empty, and the duplicate manager
          # was never converged. Nothing here is optional in the image: /bin/sh,
          # tr, basename and a shell read loop are all there. The triple printed
          # is pid ppid args, which is exactly the shape the awk below expects.
          # The single quotes are the point: the script must reach /bin/sh in
          # the container unexpanded (the variables are its own), hence the
          # SC2016 disable.
          # shellcheck disable=SC2016
          box_ps="$(${lib.getBin podmanPkg}/bin/podman exec --user 0 ${cfg.containerName} -- \
            /bin/sh -c '
              for d in /proc/[0-9]*; do
                [ -r "$d/cmdline" ] || continue
                c="$(tr "\000" " " <"$d/cmdline" 2>/dev/null)" || continue
                [ -n "$c" ] || continue
                p=$(basename "$d")
                pp=0
                while read -r k v _rest; do
                  if [ "$k" = "PPid:" ]; then pp="$v"; break; fi
                done <"$d/status" 2>/dev/null
                printf "%s %s %s\n" "$p" "$pp" "$c"
              done
            ' 2>/dev/null || true)"
          box_mgrs="$(printf '%s' "$box_ps" | awk '$3 == "/usr/lib/systemd/systemd" && $4 == "--user" { print $1 }')"
          box_mgr_count="$(printf '%s' "$box_mgrs" | grep -c . || true)"
          log "box managers: $(printf '%s' "$box_mgrs" | tr '\n' ' ')"
          if [ "$box_mgr_count" -gt 1 ]; then
            printf 'desktop-session: %d user managers in the box; converging.\n' \
              "$box_mgr_count" >&2
            log "converging $box_mgr_count managers"
            # Parent chain of every user-scope broker launch, mapped to the
            # manager it belongs to: the launch is a (grand)child of exactly
            # the manager that owns the bus.
            box_owner="$(printf '%s' "$box_ps" | awk '
              { ppid_of[$1] = $2; line_of[$1] = $0 }
              END {
                for (pid in line_of)
                  if (line_of[pid] ~ /dbus-broker-launch/ && line_of[pid] ~ /--scope user/) {
                    p = pid
                    while ((p in ppid_of) && (ppid_of[p] != 1)) p = ppid_of[p]
                    print p
                    exit
                  }
              }')"
            # Only trust the walk if it lands on a manager; otherwise (broker
            # mid-start) fall back to the oldest manager, which is the linger
            # one and therefore the stable choice.
            case " $box_mgrs " in
              *" $box_owner "*) ;;
              *) box_owner="$(printf '%s' "$box_mgrs" | head -n 1)" ;;
            esac
            # Word-splitting the pid list is intended (shellcheck disable on the
            # next line covers SC2086).
            for loser in $box_mgrs; do # shellcheck disable=SC2086
              if [ "$loser" != "$box_owner" ]; then
                log "stopping duplicate manager $loser (keeping $box_owner)"
                ${lib.getBin podmanPkg}/bin/podman exec --user 0 ${cfg.containerName} -- \
                  kill "$loser" >/dev/null 2>&1 || :
              fi
            done
            sleep 3
            log "dedupe done"
          fi
          # Reachability only -- not the write of the id. The authoritative
          # write happens inside the session enter below, because ordering is
          # what decides it: every `distrobox enter` opens a PAM session in the
          # box, and that import lands *after* anything done here. Measured on
          # a real login: this loop's read-back verified XDG_SESSION_ID=13 in
          # the manager, the session command started a second later, and the
          # units came up carrying the box's own id c31 instead -- which the
          # box's logind had already forgotten, so gnome-session-service asked
          # for a session that did not exist and mutter parked. Doing the write
          # after PAM, immediately before exec, is the fix; this loop just
          # proves a manager is there to write to.
          tries=0
          printf 'desktop-session: waiting on the box user manager.\n' >&2
          log "manager wait start"
          until ${lib.getBin pkgs.distrobox}/bin/distrobox enter --name ${cfg.containerName} -- \
            env "XDG_RUNTIME_DIR=/run/user/$box_uid" systemctl --user --no-pager show-environment >/dev/null 2>&1; do
            tries=$((tries + 1))
            if [ "$tries" -ge 12 ]; then
              printf 'desktop-session: box user manager not reachable after %ss.\n' "$((tries * 5))" >&2
              log "manager unreachable after $tries tries, giving up"
              printf 'Without a manager there is nothing to start the session under.\n' >&2
              exit 1
            fi
            sleep 5
          done
          log "box manager reachable"

          # Host-owned services have no business running in the box: the
          # container shares the host network namespace, so a box
          # NetworkManager sees the same interfaces the host NM manages --
          # two managers, one wifi chip (measured: the box one runs, answers
          # its own nmcli, and manages nothing but side channels, while the
          # session correctly sees the host). Same for avahi-daemon, which
          # would double-answer mDNS next to the host one. Masked with
          # --now, service and socket both (a bare service mask still leaves
          # the socket to trigger it). Runs every login, so a recreated
          # container converges by itself; stopping them is safe because the
          # box one manages nothing -- both devices showed externally
          # managed. The guest stays out of the host networkmanager group
          # deliberately (see modules/config/user.nix): it uses the network
          # the host provides and cannot reconfigure it or read stored keys.
          # shellcheck disable=SC2016
          if ${lib.getBin pkgs.distrobox}/bin/distrobox enter --name ${cfg.containerName} -- \
            env "DESKTOP_SESSION_LOG=$session_log" /bin/sh -c '
              for _s in NetworkManager.service avahi-daemon.service avahi-daemon.socket; do
                if sudo -n systemctl mask --now "$_s" >/dev/null 2>&1; then
                  printf "%s inner: masked %s\n" "$(date +%H:%M:%S)" "$_s"
                else
                  printf "%s inner: mask FAILED %s\n" "$(date +%H:%M:%S)" "$_s"
                fi
              done >>"$DESKTOP_SESSION_LOG" 2>/dev/null
            ' >/dev/null 2>&1; then
            log "box services masked"
          else
            log "box service masking FAILED (continuing)"
          fi

          # A bare gnome-session, deliberately NOT under dbus-run-session: the
          # container runs its own systemd --user, so the user bus already
          # exists, and dbus-run-session would *replace* it with a private bus
          # -- which is exactly what broke gnome-session with "Failed to upload
          # environment to systemd". The path is inside the container, hence not
          # a store path.
          #
          # No `exec` here, on purpose: the trap below has to run when the
          # session ends, and exec would replace this shell before it can.
          # Logout teardown: the box outlives the greeter session (its
          # processes sit in a libpod scope, not the session scope, so
          # logind's session cleanup never touches them). Without this, a
          # second login finds the previous session's units still running --
          # bus name taken, DRM master held -- and the new session fails to
          # start. Stopping the session target leaves the box running but
          # sessionless, which is exactly what a fresh login expects.
          # (box_stop itself and the trap arming live near the top of this
          # branch, so teardown runs however the session ends.)
          # NB: never export DBX_NON_INTERACTIVE=1 here, even though it looks
          # like the way to stop distrobox asking questions. It does the exact
          # opposite: it selects the "no terminal, assume yes" branch and
          # auto-creates the container from the default image. The guard above is
          # the only thing standing between a missing container and a broken one.
          # The session identity is forced INSIDE the box, after PAM has run --
          # not merely exported on the host. distrobox forwards host exports,
          # but the box's pam_systemd overwrites XDG_SESSION_ID (and TYPE) with
          # the *box* session it just created (measured: host99 in, c13 out),
          # now that the box logind actually works. That used to be harmless --
          # back when the box logind was broken, pam failed and the forwarded
          # values survived by accident. With a working box, mutter would see
          # the box session (no seat, no devices) instead of the host one and
          # stall. So the inner shell below forces the id on the session binary
          # AND writes it into the manager, which is what the units inherit --
          # gnome-session does not pass it down itself.
          # XDG_CURRENT_DESKTOP/DESKTOP need no such treatment: pam never sets
          # them, so the host exports arrive intact.
          log "starting ${cfg.gnomeSessionCommand}"
          # Single quotes again: the inner script must arrive at /bin/sh in the
          # container unexpanded, reading the variables `env` hands it.
          # shellcheck disable=SC2016
          if ${lib.getBin pkgs.distrobox}/bin/distrobox enter --name ${cfg.containerName} -- \
            env XDG_SESSION_ID="$XDG_SESSION_ID" XDG_SESSION_TYPE=wayland \
              "DBUS_SYSTEM_BUS_ADDRESS=$DBUS_SYSTEM_BUS_ADDRESS" \
              "DESKTOP_SESSION_LOG=$session_log" \
              /bin/sh -c '
                say() {
                  printf "%s inner: %s\n" "$(date +%H:%M:%S)" "$1" \
                    >>"$DESKTOP_SESSION_LOG" 2>/dev/null || :
                }
                say "id=$XDG_SESSION_ID bus=$DBUS_SYSTEM_BUS_ADDRESS"

                # Host-asset sanitisation: the fix for "cursor/icons/theme are
                # missing". distrobox forwards the ENTIRE host environment
                # into the box, and the host is NixOS while the box is Fedora.
                # Measured in the environment of a real login:
                #
                #   XCURSOR_PATH=/home/guest/.icons:...:/run/current-system/
                #     sw/share/icons -- an all-Nix list, and /usr/share/icons
                #     (where the only cursor theme in the box, Adwaita, is) 
                #     NOT in it. XCURSOR_PATH REPLACES the default search
                #     path, so no cursor resolves at all: that is the missing
                #     pointer.
                #   XDG_DATA_DIRS/XDG_CONFIG_DIRS/TERMINFO_DIRS/INFOPATH/
                #     LIBEXEC_PATH/QTWEBKIT_PLUGIN_PATH/LESSKEYIN_SYSTEM/
                #     NIX_* -- host directories, six of them nonexistent here.
                #   GTK_PATH -- host lib dirs, and /nix IS bind-mounted into
                #     this box (podman inspect: "/nix <- /nix"), so they
                #     RESOLVE: GTK3/GTK4 in the box would happily dlopen a
                #     host .so into a Fedora process.
                #   LOCALE_ARCHIVE=/run/current-system/sw/lib/locale/...
                #     -- the glibc archive of the host; the box has its own at
                #     /usr/lib/locale (verified).
                #   SYSTEMD_XKB_DIRECTORY=/etc/X11/xkb -- verified missing in
                #     the box; xkb data is /usr/share/X11/xkb here.
                #   PATH -- every entry is a host profile directory.
                #
                # The image itself needs none of this: fonts, cursor
                # adwaita-cursor-theme-50, icon adwaita-icon-theme-50,
                # gtk3/gtk4/libadwaita and /usr/share/icons/Adwaita/cursors/
                # left_ptr are all present (verified with rpm and ls). The
                # leaked variables are the whole problem, so the fix is one
                # pass here rather than a list of per-symptom patches.
                #
                # Rules, per exported variable:
                #   * value mentions a host Nix path -> drop it. PATH and
                #     SHELL are the exceptions: dropping those outright would
                #     leave children with no command search path and no login
                #     shell, so PATH is reset to the box default and SHELL
                #     is repointed at the shell this user has in the box.
                #   * absolute-path value with NO entry that exists in the
                #     box -> drop it. terminfo, locales and xkb all fall back
                #     to working box defaults (verified: /usr/share/terminfo,
                #     /usr/lib/locale/locale-archive, /usr/share/X11/xkb).
                #   * WAYLAND_DISPLAY whose socket is not in the box runtime
                #     dir -> drop it; the box compositor has not started yet,
                #     so the value can only be a host leftover.
                # /run/host is deliberately NOT a marker: it is how this
                # session reaches the host system bus. XDG_SESSION_ID, the
                # DBUS_* addresses (they start with "unix:", not "/"), HOME
                # and LANG are all kept.
                #
                # Applied to this process AND to the user manager (the
                # unset-environment/set-environment in the loop below), because
                # the units inherit the manager, and the activation upload
                # from gnome-session only sends the variables it HAS: a value
                # merely unset here would survive in the manager from the PAM
                # import of the first enter and reach gnome-shell anyway
                # (that is exactly how XCURSOR_PATH got there).
                marked() {
                  case "$1" in
                    *"/nix/store"*|*"/nix/profile"*|*"/.nix-profile"*|*"/nix/var/nix"*|*"/run/current-system"*|*"/etc/profiles/per-user"*)
                      return 0
                      ;;
                  esac
                  return 1
                }
                any_exists() {
                  _oifs=$IFS
                  IFS=:
                  for _p in $1; do
                    if [ -e "$_p" ]; then
                      IFS=$_oifs
                      return 0
                    fi
                  done
                  IFS=$_oifs
                  return 1
                }
                decide() {
                  case "$1" in
                    PATH)
                      printf "set|%s|%s\n" "$1" \
                        "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
                      ;;
                    SHELL)
                      _sh=$(getent passwd "$(id -un)" | cut -d: -f7)
                      if [ -n "$_sh" ]; then
                        printf "set|%s|%s\n" "$1" "$_sh"
                      else
                        printf "drop|%s\n" "$1"
                      fi
                      ;;
                    *)
                      printf "drop|%s\n" "$1"
                      ;;
                  esac
                }
                decision=$(mktemp) || decision=/tmp/guest-desktop-env
                env | while IFS= read -r _line; do
                  case "$_line" in
                    *=*) ;;
                    *) continue ;;
                  esac
                  _name=''${_line%%=*}
                  _val=''${_line#*=}
                  _drop=
                  if marked "$_val"; then
                    _drop=1
                  else
                    case "$_val" in
                      /*)
                        any_exists "$_val" || _drop=1
                        ;;
                    esac
                  fi
                  if [ -n "$_drop" ]; then
                    decide "$_name"
                  fi
                done >"$decision"
                if [ -n "''${WAYLAND_DISPLAY:-}" ] \
                  && [ ! -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
                  printf "drop|%s\n" "WAYLAND_DISPLAY" >>"$decision"
                fi
                stripped=""
                while IFS="|" read -r _act _name _val; do
                  [ -n "$_act" ] || continue
                  case "$_act" in
                    drop)
                      unset "$_name" || :
                      stripped="$stripped $_name"
                      systemctl --user unset-environment "$_name" \
                        || say "manager unset failed: $_name"
                      ;;
                    set)
                      export "$_name=$_val"
                      stripped="$stripped $_name:repaired"
                      systemctl --user set-environment "$_name=$_val" \
                        || say "manager set failed: $_name"
                      ;;
                  esac
                done <"$decision"
                rm -f "$decision"
                say "host env stripped:$stripped"

                for kv in \
                  "XDG_SESSION_ID=$XDG_SESSION_ID" \
                  "XDG_SESSION_TYPE=$XDG_SESSION_TYPE" \
                  "DBUS_SYSTEM_BUS_ADDRESS=$DBUS_SYSTEM_BUS_ADDRESS"; do
                  systemctl --user set-environment "$kv" || say "set failed: $kv"
                done
                # The id needs a second, stronger channel, and this is the
                # whole reason: gsm_util_export_user_environment() in
                # gnome-session uploads variable_blacklist as an UNSET list to
                # UpdateActivationEnvironment, and XDG_SESSION_ID is on that
                # blacklist ("might end up in the wrong session"). Measured:
                # the set-environment above reads back fine, then gnome-session
                # starts, and org.gnome.Shell@user.service comes up with no
                # XDG_SESSION_ID at all -- so mutter skips its env path, the
                # pid path cannot resolve a container pid, the display path
                # falls back to the BOX session record (local files only), and
                # it builds a proxy for an object that does not exist on the
                # host bus. An empty Seat property then trips
                # g_variant_get(..., "(s&o)") and g_variant_is_object_path in
                # get_seat_proxy -- exactly the two assertions in the journal
                # -- and the shell parks until systemd gives up at 50s.
                # A unit drop-in is merged into the unit itself, so that export
                # cannot take it away, and unit Environment= beats the manager
                # environment (measured: drop-in 13 vs manager 999, unit saw 13).
                #
                # Widened from one unit to the whole session: Super+L proved
                # the same disease in gsd-media-keys -- no XDG_SESSION_ID in
                # its environ, the lock call reliably fails ServiceUnknown --
                # and every other session unit is missing the id for the same
                # reason. Fixing units one at a time is whack-a-mole, so the
                # drop-in is written for each service in the session target
                # closure, enumerated live (no fixed list to rot across
                # releases; drop-ins for units that never start are inert).
                # The Shell unit that motivated the first drop-in is in the
                # closure, so it is covered by the loop like everything else.
                # Rewritten from scratch on every login, so a stale id can
                # never survive into the next session; teardown removes the
                # whole set for the same reason (linger keeps this manager
                # alive across logouts).
                dropin_written=0
                for _u in $(systemctl --user list-dependencies --plain gnome-session@gnome.target 2>/dev/null | grep '\.service$' || :); do
                  _d="$HOME/.config/systemd/user/$_u.d"
                  mkdir -p "$_d" 2>/dev/null || continue
                  if printf "[Service]\nEnvironment=XDG_SESSION_ID=%s\n" \
                    "$XDG_SESSION_ID" > "$_d/50-desktop-session.conf"; then
                    dropin_written=$((dropin_written + 1))
                  else
                    say "drop-in write FAILED: $_u"
                  fi
                done
                say "drop-ins written: $dropin_written"
                if systemctl --user daemon-reload; then
                  say "daemon-reload ok"
                else
                  say "daemon-reload FAILED"
                fi
                if systemctl --user show-environment \
                  | grep -qx "XDG_SESSION_ID=$XDG_SESSION_ID"; then
                  say "manager carries id"
                else
                  say "manager id read-back FAILED"
                fi
                exec env XDG_SESSION_ID="$XDG_SESSION_ID" XDG_SESSION_TYPE="$XDG_SESSION_TYPE" \
                  "DBUS_SYSTEM_BUS_ADDRESS=$DBUS_SYSTEM_BUS_ADDRESS" '"${cfg.gnomeSessionCommand}"'
              '; then
            log "session command exited rc=0"
          else
            session_rc=$?
            log "session command exited rc=$session_rc"
          fi
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
          distrobox container name. The guest creates this container once, with
          `containers/gnome/build.sh`; this option only names it afterwards, so
          a mismatch shows up as distrobox failing to find the container rather
          than as a silent fallback to the host shell.

          The image is Fedora 44 and must be built from
          `containers/gnome/Containerfile`:

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
        ];
        description = ''
          Devices and mounts passed into the container when it is created.

          These go through distrobox's --additional-flags, not a --device flag:
          distrobox has no --device option and fails with "Invalid flag
          '--device'". --additional-flags does reach the runtime. Confirm it
          from `distrobox create --verbose`, which prints `Non-CDI device
          /dev/dri` for each one accepted.

          Do NOT check `podman inspect --format '{{json .HostConfig.Devices}}'`
          for this: distrobox always passes --privileged, and podman returns an
          empty device list for privileged containers regardless of what was
          requested (GetDevices skips the spec entirely when priv is set), so
          that field is always []. HostConfig.Init is unrelated too -- it means
          an init binary was injected, not that systemd is the box's init.

          Why --device rather than --volume for /dev/dri: /dev/dri is
          bind-mounted by distrobox implicitly, which makes the devices
          *visible* but leaves the host's gid (video, 26) unmapped inside a
          rootless userns, so /dev/dri/card0 ends up nobody:nobody 0660 and
          cannot be opened. Passing the device explicitly makes the runtime set
          it up with permissions the container user actually has. The symptom
          to recognise is a container where `ls /dev/dri` works and open(O_RDWR)
          on card0 does not.

          Deliberately NOT the host system bus or the session files, even though
          mutter needs both (see below). An earlier version of this module
          bind-mounted `/run/dbus/system_bus_socket` and
          `/run/systemd/sessions` into the box, and that broke the box itself:
          every box client of the system bus -- including the box's own logind
          and PID 1 -- suddenly talked to the HOST, so the box's logind could
          no longer start the box's user manager (host polkit denies the
          StartUnit with "interactive authentication"), `user@guest.service`
          never came up, polkit died in a restart loop owning nobody's name,
          and gnome-session aborted with "No session bus running!" before
          mutter ever ran. One bus cannot serve two systems.

          So the box keeps its own system bus (its own dbus-broker serves its
          own logind, PID 1, polkit and user manager), and only the *session*
          is pointed at the host bus: the dispatcher exports
          `DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/host/run/dbus/system_bus_socket`
          (reachable through distrobox's own host-root mount, which -- unlike
          anything under the box's `/run` -- survives the box's init), and
          GDBus honors that variable, so mutter and the session daemons talk
          to host logind while everything box-internal stays local. The
          session *file* still has to be rebound into the box at login (see
          the dispatcher): `sd_session_is_active` -- which is how mutter
          validates `XDG_SESSION_ID` -- never talks to logind. It reads
          `/run/systemd/sessions/<id>` directly (`sd-login.c:
          file_of_session`; a missing file surfaces as the `ENXIO` "No such
          device or address" failure).

          The remaining deliberate holes in the container boundary are therefore
          per-session, not per-container: the box sees the guest's host session
          state and can talk to host system services as the unprivileged guest
          uid. D-Bus policy still applies, so privileged operations are denied --
          but enumeration (sessions, devices) is visible. There is no narrower
          option: logind is the only path mutter accepts.
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
        # Lingering, declaratively: without it the guest's user units only
        # start at login, and rootless podman loses its systemd user session
        # (falling back to cgroupfs with a warning). With it the user manager
        # is always there. /var/lib/systemd/linger persists via impermanence's
        # /var/lib/systemd entry, so this survives reboots.
        linger = true;
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

      # distrobox and buildah on PATH for the guest, for the one-time creation
      # commands in docs/guest-desktop.md and containers/gnome/build.sh.
      # buildah is not optional: `podman build` is a thin frontend over it,
      # and without it the image build fails with "buildah not found". The
      # dispatcher and the login hook below use absolute store paths and do
      # not depend on this.
      environment.systemPackages = [
        pkgs.distrobox
        pkgs.buildah
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
