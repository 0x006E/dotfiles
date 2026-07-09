{ delib, ... }:
delib.module {
  name = "desktop.noctalia";
  home.always =
    { ... }:
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      programs.noctalia = {
        enable = true;
        settings = {
          shell = {
            avatar_path = "/home/nithin/.face";
            corner_radius_scale = 0.2;
            clipboard_enabled = true;
          };
          wallpaper = {
            default = {
              path = config.stylix.image;
            };
            directory = toString (
              pkgs.runCommand "wallpaper-dir" { } ''
                mkdir $out
                cp ${config.stylix.image} $out/wallpaper.jpg
              ''
            );
          };
          theme = {
            mode = "dark";
          };
          nightlight = {
            enabled = true;
          };
          audio = {
            enable_overdrive = true;
          };
          location = {
            name = "Trivandrum, Kerala";
          };
          bar.main = {
            position = "left";
            capsule = true;
            start = [
              "control-center"
              "network"
              "bluetooth"
              "sysmon"
              "active_window"
              "media"
            ];
            center = [ "workspaces" ];
            end = [
              "battery"
              "notifications"
              "volume"
              "tray"
              "clock"
            ];
          };

          widget.control-center = {
            # use_distro_logo has been removed in v5 in favor of theming/custom icons
          };
          widget.workspaces = {
            display = "name";
            hide_when_empty = false;
          };
          widget.battery = {
            show_label = true;
            warning_threshold = 30;
          };

          widget.clock = {
            format = "{:%H:%M}";
            vertical_format = "{:%H %M}";
            # use_monospaced_font and use_primary_color are handled by the v5 theme engine now
          };
        };
      };
    };
}
