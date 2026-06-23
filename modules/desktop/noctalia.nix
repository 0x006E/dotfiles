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
            directory = toString ./.;
          };
          theme = {
            mode = "dark";
          };
          nightlight = {
            enabled = true;
            auto_schedule = true;
          };
          audio = {
            volume_overdrive = true;
          };
          weather = {
            location = "Trivandrum, Kerala";
          };
          bar.main = {
            density = "compact";
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
            use_distro_logo = true;
          };
          widget.workspaces = {
            display = "name";
            hide_when_empty = false;
          };
          widget.battery = {
            show_percentage = true;
            warning_threshold = 30;
          };
          widget.clock = {
            format = "{:%H:%M}";
            vertical_format = "{:%H %M}";
            use_monospaced_font = true;
            use_primary_color = true;
          };
        };
      };
    };
}
