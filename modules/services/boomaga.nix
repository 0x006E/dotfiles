{ delib, pkgs, ... }:
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
      # drivers in nixpkgs.
      services.printing.drivers = [ pkgs.boomaga ];
      services.dbus.packages = [ pkgs.boomaga ];

      # Spool dirs for the CUPS backend, which runs as cups:lp and hands
      # each job file to the printing user at runtime.
      systemd.tmpfiles.rules = [
        "d /var/cache/boomaga 0775 root lp - -"
        "d /var/cache/boomaga/${username} 0770 ${username} lp - -"
      ];

      environment.systemPackages = [ pkgs.boomaga ];

      # The backend chowns the spool file and setuids to the job owner,
      # i.e. it must run as root, but cupsd spawns backends as cups:lp.
      # Serve a setuid-root wrapper from cupsd's ServerBin tree instead
      # of the plain store binary.
      security.wrappers.boomaga-backend = {
        owner = "root";
        group = "root";
        setuid = true;
        source = "${pkgs.boomaga}/lib/cups/backend/boomaga";
      };

      services.printing.bindirCmds = ''
        rm -f $out/lib/cups/backend/boomaga
        ln -s /run/wrappers/bin/boomaga-backend $out/lib/cups/backend/boomaga
      '';
    };
}
