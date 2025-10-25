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
    colors = with config.lib.stylix.colors; {
      mError = "#${base08}";
      mOnError = "#${base00}";
      mOnPrimary = "#${base00}";
      mOnSecondary = "#${base00}";
      mOnSurface = "#${base04}";
      mOnSurfaceVariant = "#${base04}";
      mOnTertiary = "#${base00}";
      mOutline = "#${base02}";
      mPrimary = "#${base0B}";
      mSecondary = "#${base0A}";
      mShadow = "#${base00}";
      mSurface = "#${base00}";
      mSurfaceVariant = "#${base01}";
      mTertiary = "#${base0D}";
    };
  };
}
