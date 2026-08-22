{ delib, ... }:
delib.module {
  name = "desktop.noctalia";

  nixos.always =
    { ... }:
    {
      config,
      ...
    }:
    {
      environment.etc."wallpapers/current".source = config.stylix.image;
    };

  home.always =
    { myconfig, ... }:
    { lib, ... }:
    {
      programs.noctalia = {
        enable = true;
        settings = {
          shell = {
            avatar_path = "/home/${myconfig.constants.username}/.face";
            corner_radius_scale = 0.2;
            clipboard_enabled = true;
          };
          wallpaper = {
            enabled = true;
            # Stable path that survives rebuilds/GC; overrides the HM module's
            # volatile config.stylix.image default.
            default.path = lib.mkForce "/etc/wallpapers/current";
            directory = lib.mkForce "/etc/wallpapers";
          };
          # theme.mode is intentionally unset: Stylix's noctalia target drives
          # it from the active rice polarity (dark/light).
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
          };
        };
      };
    };
}
