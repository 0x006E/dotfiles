{
  pkgs,
  ...
}:
{
  # Networking and Discovery
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Printer Configuration
  hardware = {
    # Virtual Printer Setup
    printers = {
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

    # Scanner Support
    sane.enable = true;
  };

  # Printing Services
  services = {
    # D-Bus Integration
    dbus.packages = [ pkgs.boomaga ];

    # Printer Drivers
    printing.drivers = with pkgs; [
      hplipWithPlugin
      boomaga
    ];
  };

  # User and Group Configuration
  users.users.nithin.extraGroups = [
    "scanner"
    "lp"
  ];

  # Temporary Files Setup
  systemd.tmpfiles.rules = [
    "d /var/cache/boomaga 0775 root lp - -"
    "d /var/cache/boomaga/nithin 0770 nithin lp - -"
  ];

  # Required Packages
  environment.systemPackages = with pkgs; [
    boomaga
  ];
}
