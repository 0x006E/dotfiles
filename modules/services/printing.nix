{
  delib,
  pkgs,
  pkgs-small,
  ...
}:
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
        sane.enable = true;
        sane.extraBackends = [ pkgs-small.hplipWithPlugin ];
      };

      services = {
        printing.drivers = [
          pkgs-small.hplipWithPlugin
        ];
      };

      users.users.${username}.extraGroups = [
        "scanner"
        "lp"
      ];

      environment.systemPackages = with pkgs; [
        simple-scan
      ];
    };
}
