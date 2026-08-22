{ delib, pkgs, ... }:
delib.module {
  name = "desktop.user-services";
  options = delib.singleEnableOption true;

  home.ifEnabled = { myconfig, cfg, ... }: {
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
