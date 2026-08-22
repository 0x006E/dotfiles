{ delib, ... }:
delib.module {
  name = "desktop.user-services";

  home.always =
    { ... }:
    {
      pkgs,
      ...
    }:
    {
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
