{
  config,
  pkgs,
  ...
}:
{
  programs.noctalia-shell = {
    enable = true;
    settings = {
      settingsVersion = 15;
      bar = {
        density = "compact";
        position = "left";
        showCapsule = true;
        backgroundOpacity = 0;
        widgets = {
          left = [
            {
              id = "SidePanelToggle";
              useDistroLogo = true;
            }
            {
              id = "WiFi";
            }
            {
              id = "Bluetooth";
            }
            {
              id = "SystemMonitor";
            }
            {
              id = "ActiveWindow";
            }
            {
              id = "MediaMini";
            }
          ];
          center = [
            {
              hideUnoccupied = false;
              id = "Workspace";
              labelMode = "name";
            }
          ];
          right = [
            {
              alwaysShowPercentage = true;
              id = "Battery";
              warningThreshold = 30;
            }
            {
              id = "NotificationHistory";
            }
            {
              id = "Volume";
            }
            {
              id = "Tray";
            }
            {
              formatHorizontal = "HH:mm";
              formatVertical = "HH mm";
              id = "Clock";
              useMonospacedFont = true;
              usePrimaryColor = true;
            }
          ];
        };
      };
      general = {
        avatarImage = "/home/nithin/.face";
        radiusRatio = 0.2;
      };
      location = {
        monthBeforeDay = false;
        name = "Trivandrum, Kerala";
      };
      wallpaper = {
        enabled = true;
        setWallpaperOnAllMonitors = true;
        defaultWallpaper = ./wallpaper.jpg;
      };
      appLauncher = {
        enableClipboardHistory = true;
      };
      ui = {
        fontDefault = "FreeSans";
        fontFixed = "Commit Mono";
      };
      colorSchemes = {
        useWallpaperColors = true;
        darkMode = true;
        matugenSchemeType = "scheme-expressive";
      };
      nightLight = {
        enabled = true;
        autoSchedule = true;
      };
    };
  };
}
