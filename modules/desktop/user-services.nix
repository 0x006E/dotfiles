{ delib, ... }:
delib.module {
  name = "desktop.user-services";

  home.always = { myconfig, ... }: { pkgs, config, lib, ... }: {
    services = {
      udiskie.enable = true;

      kdeconnect = {
        enable = true;
        indicator = true;
      };

      flameshot = {
        enable = true;
        package = pkgs.flameshot.override { enableWlrSupport = true; };
        settings.General = {
          disabledTrayIcon = true;
          showStartupLaunchMessage = false;
        };
      };
    };
  };
}
