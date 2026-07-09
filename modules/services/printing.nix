{ delib, inputs, ... }:
delib.module {
  name = "services.printing";

  nixos.always =
    { myconfig, ... }:
    {
      pkgs,
      config,
      lib,
      pkgs-unstable,
      ...
    }:
    {
      services.printing.enable = true;
      services.avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };

      hardware = {
        printers = {
          ensurePrinters = [
            {
              name = "Boomaga";
              deviceUri = "boomaga:/";
              model = "boomaga/boomaga.ppd";
              description = "Boomaga Virtual Printer";
              location = "Local Virtual Printer";
              ppdOptions = { };
            }
          ];
        };
        sane.enable = true;
        sane.extraBackends = [ pkgs-unstable.hplipWithPlugin ];
      };

      services = {
        dbus.packages = [ pkgs.boomaga ];
        printing.drivers = with pkgs; [
          pkgs-unstable.hplipWithPlugin
          boomaga
        ];
      };

      users.users.nithin.extraGroups = [
        "scanner"
        "lp"
      ];

      systemd.tmpfiles.rules = [
        "d /var/cache/boomaga 0775 root lp - -"
        "d /var/cache/boomaga/nithin 0770 nithin lp - -"
      ];

      environment.systemPackages = with pkgs; [
        boomaga
        simple-scan
      ];
    };
}
