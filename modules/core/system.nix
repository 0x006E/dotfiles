{ delib, ... }:
delib.module {
  name = "core.system";

  nixos.always = { myconfig, ... }: { pkgs, config, lib, ... }: {
    systemd = {
      settings.Manager = {
        DefaultTimeoutStopSec = "10s";
      };
      user.extraConfig = "DefaultTimeoutStopSec=10s";
      sleep.extraConfig = ''
        MemorySleepMode=deep
      '';
    };

    security = {
      rtkit.enable = true;
      pam.services.hyprlock = { };
    };

    time = {
      timeZone = "Asia/Kolkata";
      hardwareClockInLocalTime = true;
    };

    system.stateVersion = "24.05";
  };
}
