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
      # i.e. it needs root-like privilege, but cupsd spawns backends as
      # cups:lp — and cupsd refuses backends with the setuid bit set
      # ("insecure permissions"). So install a root-owned copy carrying
      # only the capabilities the backend needs (chown/fowner for the
      # spool files, setuid/setgid to become the job owner) and serve it
      # from cupsd's ServerBin tree. File capabilities don't show up in
      # st_mode, so cupsd's permission check accepts the binary.
      system.activationScripts.boomagaBackend = lib.stringAfter [ "users" "groups" ] ''
        mkdir -p /var/lib/boomaga
        cp -f ${pkgs.boomaga}/lib/cups/backend/boomaga /var/lib/boomaga/backend
        chown root:lp /var/lib/boomaga/backend
        chmod 0750 /var/lib/boomaga/backend
        ${pkgs.libcap}/bin/setcap cap_chown,cap_fowner,cap_setuid,cap_setgid+ep /var/lib/boomaga/backend
      '';

      services.printing.bindirCmds = ''
        rm -f $out/lib/cups/backend/boomaga
        ln -s /var/lib/boomaga/backend $out/lib/cups/backend/boomaga
      '';
    };
}
