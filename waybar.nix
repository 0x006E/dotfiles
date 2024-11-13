{
  pkgs,
  pkgs-unstable,
  ...
}:
{
  programs.waybar = {
    enable = true;
    package = pkgs-unstable.waybar;
    systemd.enable = false;
    # style = ''
    #
    #   window#waybar {
    #     background: transparent;
    #
    #     border-bottom: none;
    #   }
    #
    #   * {
    #     font-size: 12px;
    #     font-family: monospace;
    #   }
    # '';
    settings = [
      {
        layer = "top";
        position = "left";
        tray = {
          spacing = 10;
        };
        modules-center = [ "niri/window" ];
        modules-left = [
          "niri/workspaces"
          "niri/mode"
        ];
        modules-right = [
          "pulseaudio"
          "network"
          "cpu"
          "memory"
          "temperature"
          "battery"
          "clock"
          "tray"
        ];
        "niri/workspaces" = {
          format = "{icon}";
          format-icons = {
            terminal = "";
            browser = "";
            discord = "";
            chat = "<b></b>";
            active = "";
            default = "";
          };
        };
        battery = {
          format = "{capacity}%\n{icon}";
          format-alt = "{time}\n{icon}";
          format-charging = "{capacity}%\n";
          format-icons = [
            ""
            ""
            ""
            ""
            ""
          ];
          format-plugged = "{capacity}%\n";
          states = {
            critical = 15;
            warning = 30;
          };
        };
        "niri/window" = {
          # format = "{}";
          # icon = true;
        };
        clock = {
          format = "{:%H}\n{:%M}";
          # format-alt = "{:%Y-%m-%d}";
          tooltip-format = "{:%Y-%m-%d | %H:%M}";
        };
        cpu = {
          format = "{usage}%\n";
          tooltip = false;
        };
        memory = {
          format = "{}%\n";
        };
        network = {
          interval = 1;
          format-alt = "{ifname}: {ipaddr}/{cidr}";
          format-disconnected = "Disconnected\n⚠";
          format-ethernet = "{ifname}: {ipaddr}/{cidr}   up: {bandwidthUpBits} down: {bandwidthDownBits}";
          format-linked = "{ifname}\n(No IP)\n ";
          format-wifi = "({signalStrength}%)\n ";
          tooltip-format = "{essid}";
        };
        pulseaudio = {
          format = "{volume}%\n{format_source}";
          format-bluetooth = "{volume}%\n{icon}\n{format_source}";
          format-bluetooth-muted = "\n{icon}\n{format_source}";
          format-icons = {
            car = "";
            default = [
              ""
              ""
              ""
            ];
            handsfree = "";
            headphones = "";
            headset = "";
            phone = "";
            portable = "";
          };
          format-muted = "\n{format_source}";
          format-source = "{volume}%\n";
          format-source-muted = "";
          on-click = "pavucontrol";
        };
        "niri/mode" = {
          format = ''<span style="italic">{}</span>'';
        };
        temperature = {
          critical-threshold = 80;
          format = "{temperatureC}°C\n{icon}";
          format-icons = [
            ""
            ""
            ""
          ];
        };
      }
    ];
  };
}
