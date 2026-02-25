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
        widgets = {
          left = [
            {
              id = "ControlCenter";
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
        directory = ./.;
      };
      appLauncher = {
        enableClipboardHistory = true;
      };
      colorSchemes = {
        useWallpaperColors = false;
        darkMode = true;
        # matugenSchemeType = "scheme-fruit-salad";
      };
      nightLight = {
        enabled = true;
        autoSchedule = true;
      };
      audio = {
        volumeOverdrive = true;
      };
    };
  };
}
