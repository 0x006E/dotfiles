{ delib, inputs, ... }:
delib.module {
  name = "core.networking";

  nixos.always =
    { myconfig, ... }:
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      imports = [ inputs.erosanix.nixosModules.protonvpn ];
      networking = {
        hostName = "ntsv";
        networkmanager = {
          enable = true;
          connectionConfig = {
            "ipv4.ignore-auto-dns" = "yes";
            "ipv6.ignore-auto-dns" = "yes";
          };
        };
        nameservers = [
          "100.100.100.100"
          "45.90.28.0#8361b6.dns.nextdns.io"
          "45.90.30.0#8361b6.dns.nextdns.io"
          "2a07:a8c0::83:61b6#8361b6.dns.nextdns.io"
          "2a07:a8c1::83:61b6#8361b6.dns.nextdns.io"
        ];
        firewall.enable = false;
        firewall.checkReversePath = false;
      };

      time = {
        timeZone = "Asia/Kolkata";
        hardwareClockInLocalTime = true;
      };

      services.tailscale.enable = true;
      services.resolved = {
        enable = true;
        settings.Resolve.DNSOverTLS = "opportunistic";
      };
    };
}
