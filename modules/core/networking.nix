{ delib, inputs, ... }:
delib.module {
  name = "core.networking";

  nixos.always = { myconfig, ... }: { pkgs, config, lib, ... }: {
    imports = [ inputs.erosanix.nixosModules.protonvpn ];
    networking = {
      hostName = "ntsv";
      networkmanager.enable = true;
      nameservers = [ "100.100.100.100" ];
      firewall.enable = false;
      firewall.checkReversePath = false;
    };

    time = {
      timeZone = "Asia/Kolkata";
      hardwareClockInLocalTime = true;
    };

    services.tailscale.enable = true;
    services.resolved.enable = true;
  };
}
