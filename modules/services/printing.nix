{ delib, pkgs, pkgs-small, ... }:
delib.module {
  name = "services.printing";
  options = delib.singleEnableOption true;

  nixos.ifEnabled =
    { myconfig, ... }:
    let
      inherit (myconfig.constants) username;
    in
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
        sane.extraBackends = [ pkgs-small.hplipWithPlugin ];
      };

      services = {
        dbus.packages = [ pkgs.boomaga ];
        printing.drivers = with pkgs; [
          pkgs-small.hplipWithPlugin
          boomaga
        ];
      };

      users.users.${username}.extraGroups = [
        "scanner"
        "lp"
      ];

      systemd.tmpfiles.rules = [
        "d /var/cache/boomaga 0775 root lp - -"
        "d /var/cache/boomaga/${username} 0770 ${username} lp - -"
      ];

      environment.systemPackages = with pkgs; [
        boomaga
        simple-scan
      ];
    };
}
