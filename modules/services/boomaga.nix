{
  delib,
  pkgs,
  lib,
  ...
}:
delib.module {
  name = "services.boomaga";
  options = delib.singleEnableOption true;

  nixos.ifEnabled =
    { myconfig, ... }:
    let
      inherit (myconfig.constants) username;
    in
    {
      # Virtual printer queue: print to Boomaga to preview/reorder, then
      # forward to a real printer from the GUI.
      hardware.printers.ensurePrinters = [
        {
          name = "Boomaga";
          deviceUri = "boomaga:/";
          model = "boomaga/boomaga.ppd";
          description = "Boomaga Virtual Printer";
          location = "Local Virtual Printer";
          ppdOptions = { };
        }
      ];

      # Exposes $out/lib/cups/backend/boomaga (CUPS ServerBin tree) and
      # $out/share/cups/model/boomaga (PPDs), like hplip and other
      # drivers in nixpkgs. The backend runs unprivileged as cups:lp: it
      # publishes each job as a group-readable spool file and exits 0;
      # the user session helper below opens it in the GUI.
      services.printing.drivers = [ pkgs.boomaga ];
      services.dbus.packages = [ pkgs.boomaga ];

      # Spool dirs for the CUPS backend (backend runs as cups:lp, job
      # files are chmodded 0640 so the printing user, in group lp, and
      # the session helper can read them).
      systemd.tmpfiles.rules = [
        "d /var/cache/boomaga 0775 root lp - -"
        "d /var/cache/boomaga/${username} 0770 ${username} lp - -"
      ];

      environment.systemPackages = [ pkgs.boomaga ];

      # Remove the privileged backend copy installed by the earlier
      # capabilities-based revision; cupsd serves the plain store
      # backend again via services.printing.drivers.
      system.activationScripts.boomagaBackendCleanup = lib.stringAfter [ "users" "groups" ] ''
        rm -f /var/lib/boomaga/backend
        rmdir /var/lib/boomaga 2>/dev/null || true
      '';
    };

  home.ifEnabled =
    { myconfig, ... }:
    let
      inherit (myconfig.constants) username;
      spoolDir = "/var/cache/boomaga/${username}";
      watch = pkgs.writeShellScript "boomaga-spool-watch" ''
        set -euo pipefail
        spool="${spoolDir}"
        lock="$spool/.watch.lock"

        [[ -d "$spool" ]] || exit 0

        # Serialize concurrent triggers; the sibling run drains the queue.
        if [[ "''${BOOMAGA_WATCH_LOCKED:-0}" != 1 ]]; then
          flock -n "$lock" env BOOMAGA_WATCH_LOCKED=1 "$0" || exit 0
          exit 0
        fi

        # Prune temp files abandoned by backends killed mid-write.
        find "$spool" -maxdepth 1 -name 'in_*.tmp' -mmin +1440 -delete 2>/dev/null || true

        # Pending jobs, oldest first.
        mapfile -t jobs < <(ls -tr "$spool"/in_*.cboo.autoremove 2>/dev/null || true)
        [[ "''${#jobs[@]}" -eq 0 ]] && exit 0

        # The --started-from-cups forwarder only speaks D-Bus: make sure
        # the GUI singleton is up (starting it is a no-op when running).
        has_owner() {
          busctl --user call org.freedesktop.DBus /org/freedesktop/DBus \
            org.freedesktop.DBus NameHasOwner s org.boomaga 2>/dev/null | grep -q 'b true'
        }
        if ! has_owner; then
          systemctl --user start boomaga-gui.service
          for _ in $(seq 1 50); do
            has_owner && break
            sleep 0.2
          done
        fi

        for job in "''${jobs[@]}"; do
          [[ -e "$job" ]] || continue
          ${pkgs.boomaga}/bin/boomaga --started-from-cups "$job"
          # The GUI consumes the file on load (copies to a private tmp
          # and deletes the original); wait for that first.
          for _ in $(seq 1 75); do
            [[ -e "$job" ]] || break
            sleep 0.2
          done
        done
        exit 0
      '';
    in
    {
      systemd.user.paths.boomaga-spool = {
        Unit.Description = "Open new Boomaga print jobs";
        Path = {
          PathModified = spoolDir;
          Unit = "boomaga-job.service";
        };
        Install.WantedBy = [ "default.target" ];
      };

      systemd.user.services.boomaga-job = {
        Unit.Description = "Forward new Boomaga spool files to the GUI";
        Service = {
          Type = "oneshot";
          Environment = "PATH=${
            lib.makeBinPath [
              pkgs.boomaga
              pkgs.dbus
              pkgs.systemd
              pkgs.util-linux
              pkgs.findutils
              pkgs.coreutils
              pkgs.gnugrep
            ]
          }";
          ExecStart = "${watch}";
        };
      };

      # On-demand GUI singleton for the forwarder above; idle otherwise.
      systemd.user.services.boomaga-gui = {
        Unit.Description = "Boomaga virtual printer GUI";
        Service.ExecStart = "${pkgs.boomaga}/bin/boomaga";
      };
    };
}
