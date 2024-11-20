{
  pkgs,
  lib,
  config,
  ...
}:
let
  colorNames = [
    "base00"
    "base01"
    "base02"
    "base03"
    "base04"
    "base05"
    "base06"
    "base07"
    "base08"
    "base09"
    "base0A"
    "base0B"
    "base0C"
    "base0D"
    "base0E"
    "base0F"
  ];

  # Colors used in the markup
  colors = config.lib.stylix.colors.withHashtag;
  yellow = colors.base0A;
  peach = colors.base09;
  red = colors.base08;
  green = colors.base0B;
  secondary = colors.base0E;

  defineColor = name: value: "@define-color ${name} ${value};";

  markup = color: text: "<span color=\"${color}\" style=\"oblique\">${text}</span>";
in
{
  # Stylix injects CSS that I do not want,
  # so we style waybar for ourselves
  stylix.targets.waybar.enable = false;

  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style =
      lib.strings.concatStringsSep "\n" (
        # Convert the colors attribute set to GTK color declarations
        builtins.map (color: defineColor color colors.${color}) colorNames
      )
      +
        # Append the main CSS file
        (builtins.readFile ./style.css)
      +
        # Use monospace font
        ''
          /* Font family injected by Nix */
          * {
            font-family: ${config.stylix.fonts.monospace.name};
          }
        '';
    settings = [
      {
        layer = "top";
        position = "left";
        width = 28;
        margin = "2 0 2 2";
        spacing = 2;
        modules-left = [
          "clock"
          "custom/sep"
          "group/connection"
          "custom/sep"
          "tray"
        ];
        modules-center = [
          "niri/workspaces"
        ];
        modules-right = [
          "temperature"
          "custom/sep"
          "privacy"
          "custom/sep"
          "battery"
          "custom/sep"
          "pulseaudio"
          "custom/powermenu"
        ];
        "custom/sep" = {
          format = "";
        };
        "custom/powermenu" = {
          on-click = "~/.config/wofi/scripts/wofipowermenu.py";
          rotate = 90;
          format = "";
          icon-size = 16;
          tooltip = false;
        };
        "niri/workspaces" = {
          format = "{icon}";
          icon-size = 16;
          rotate = 90;
          format-icons = {
            # active = "";
            browser = "z";
            # chat = "<b></b>";
            default = "o";
            # discord = "";
            terminal = "t";
          };
        };
        clock = {
          tooltip = true;
          format = "{:%H\n%M}";
          tooltip-format = "{:%Y-%m-%d}";
        };
        tray = {
          icon-size = 16;
          show-passive-items = "true";
        };
        temperature = {
          rotate = 90;
          hwmon-path = "/sys/class/hwmon/hwmon3/temp1_input";
          critical-threshold = 80;
          format = "{icon} {temperatureC}°C";
          format-icons = [
            ""
            ""
            ""
          ];
        };
        network = {
          format = "{icon}";
          format-icons = {
            wifi = [
              "󰤨"
            ];
            ethernet = [
              "󰈀"
            ];
            disconnected = [
              "󰖪"
            ];
          };
          format-wifi = "󰤨";
          format-ethernet = "󰈀";
          format-disconnected = "󰖪";
          format-linked = "󰈁";
          tooltip = false;
          on-click = "pgrep -x rofi &>/dev/null && notify-send rofi || networkmanager_dmenu";
        };
        "network#speed" = {
          format = " {bandwidthDownBits} ";
          rotate = 90;
          interval = 5;
          tooltip-format = "{ipaddr}";
          tooltip-format-wifi = "{essid} ({signalStrength}%)   \n{ipaddr} | {frequency} MHz{icon} ";
          tooltip-format-ethernet = "{ifname} 󰈀 \n{ipaddr} | {frequency} MHz{icon} ";
          tooltip-format-disconnected = "Not Connected to any type of Network";
          tooltip = true;
          on-click = "pgrep -x rofi &>/dev/null && notify-send rofi || networkmanager_dmenu";
        };
        bluetooth = {
          format-on = "";
          format-off = "󰂲";
          format-disabled = "";
          format-connected = "<b></b>";
          tooltip-format = "{controller_alias}\t{controller_address}\n\n{num_connections} connected";
          tooltip-format-connected = "{controller_alias}\t{controller_address}\n\n{num_connections} connected\n\n{device_enumerate}";
          tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
          tooltip-format-enumerate-connected-battery = "{device_alias}\t{device_address}\t{device_battery_percentage}%";
          on-click = "rofi-bluetooth -config ~/.config/rofi/menu.d/network.rasi -i";
        };
        "bluetooth#status" = {
          format-on = "";
          format-off = "";
          format-disabled = "";
          format-connected = "<b>{num_connections}</b>";
          format-connected-battery = "<small><b>{device_battery_percentage}%</b></small>";
          tooltip-format = "{controller_alias}\t{controller_address}\n\n{num_connections} connected";
          tooltip-format-connected = "{controller_alias}\t{controller_address}\n\n{num_connections} connected\n\n{device_enumerate}";
          tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
          tooltip-format-enumerate-connected-battery = "{device_alias}\t{device_address}\t{device_battery_percentage}%";
          on-click = "rofi-bluetooth -config ~/.config/rofi/menu.d/network.rasi -i";
        };
        "group/network" = {
          orientation = "vertical";
          drawer = {
            transition-duration = 500;
            transition-left-to-right = true;
          };
          modules = [
            "network"
            "network#speed"
          ];
        };
        "group/bluetooth" = {
          orientation = "inherit";
          drawer = {
            transition-duration = 500;
            transition-left-to-right = true;
          };
          modules = [
            "bluetooth"
            "bluetooth#status"
          ];
        };
        "group/connection" = {
          orientation = "vertical";
          modules = [
            "group/network"
            "group/bluetooth"
          ];
        };
        battery = {
          rotate = 90;
          states = {
            good = 95;
            warning = 30;
            critical = 15;
          };
          format = "{icon}";
          format-charging = "<b>{icon} </b>";
          format-full = "<span color='#82A55F'><b>{icon}</b></span>";
          format-icons = [
            "󰁻"
            "󰁼"
            "󰁾"
            "󰂀"
            "󰂂"
            "󰁹"
          ];
          tooltip-format = "{timeTo} {capacity} % | {power} W";
        };
        privacy = {
          orientation = "vertical";
          icon-size = 16;
          modules = [
            { type = "screenshare"; }
            { type = "audio-in"; }
          ];
        };
        pulseaudio = {
          rotate = 90;
          icon-size = 16;
          format = "{icon} {volume}% {format_source}";
          format-bluetooth = "${markup secondary "vol bt"} {volume}% {format_source}";
          format-bluetooth-muted = "${markup red "muted bt"} {format_source}";
          format-muted = "${markup red "muted"} {format_source}";
          format-source = "${markup secondary "mic"} {volume}%";
          format-source-muted = markup red "mic";
          format-icons = {
            headphone = "${markup secondary "vol"}";
            hands-free = "${markup secondary "handsfree"}";
            headset = "${markup secondary "headset"}";
            phone = "${markup secondary "phone"}";
            portable = "${markup secondary "portable"}";
            car = "${markup secondary "car"}";
            default = "${markup secondary "vol"}";
          };
          on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
        };
      }
    ];
  };
}
