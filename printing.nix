{ pkgs, ... }:
let
  boomaga = pkgs.libsForQt5.callPackage ./boomaga.nix { };
in
{
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
  environment.systemPackages = with pkgs; [ boomaga ];

  hardware.printers = {
    ensurePrinters = [
      {
        name = "Boomaga";
        deviceUri = "boomaga:/";
        model = "boomaga/boomaga.ppd";
        description = "Boomaga Virtual Printer";
        location = "Local Virtual Printer";
        ppdOptions = {
          # Add any specific PPD options here if needed
        };
      }
    ];
  };
  systemd.tmpfiles.rules = [
    "d /var/cache/boomaga 0775 root lp - -"
    "d /var/cache/boomaga/nithin 0770 nithin lp - -"
  ];
  services.dbus.packages = [ boomaga ];
  services.printing.drivers = with pkgs; [
    hplipWithPlugin
    boomaga
  ];
}
