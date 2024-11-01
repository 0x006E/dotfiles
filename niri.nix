{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:
with lib;
let
  binds =
    {
      suffixes,
      prefixes,
      substitutions ? { },
    }:
    let
      replacer = replaceStrings (attrNames substitutions) (attrValues substitutions);
      format =
        prefix: suffix:
        let
          actual-suffix =
            if isList suffix.action then
              {
                action = head suffix.action;
                args = tail suffix.action;
              }
            else
              {
                inherit (suffix) action;
                args = [ ];
              };

          action = replacer "${prefix.action}-${actual-suffix.action}";
        in
        {
          name = "${prefix.key}+${suffix.key}";
          value.action.${action} = actual-suffix.args;
        };
      pairs =
        attrs: fn:
        concatMap (
          key:
          fn {
            inherit key;
            action = attrs.${key};
          }
        ) (attrNames attrs);
    in
    listToAttrs (pairs prefixes (prefix: pairs suffixes (suffix: [ (format prefix suffix) ])));
in
{
  programs.niri = {
    settings = {
      input.keyboard.xkb.layout = "us";
      input.focus-follows-mouse = {
        enable = true;
      };
      input.mouse.accel-speed = 1.0;
      input.touchpad = {
        tap = true;
        dwt = true;
        natural-scroll = true;
        click-method = "clickfinger";
      };

      input.tablet.map-to-output = "eDP-1";
      input.touch.map-to-output = "eDP-1";

      prefer-no-csd = true;
      workspaces = {
        terminal = { };
        browser = { };
      };
      layout = {
        gaps = 10;
        struts.left = 0;
        struts.right = 0;
        focus-ring.enable = false;
        border = {
          enable = true;
          width = 2;
          active.gradient = {
            from = "#ADEFD1";
            to = "#00203F";
            angle = 45;
            relative-to = "workspace-view";
          };
          inactive.gradient = {
            from = "#00203F";
            to = "#ADEFD1";
            angle = 45;
            relative-to = "workspace-view";
          };
        };
      };

      hotkey-overlay.skip-at-startup = true;

      binds =
        with config.lib.niri.actions;
        let
          sh = spawn "sh" "-c";
        in
        lib.attrsets.mergeAttrsList [
          {
            "Mod+T".action = sh "niri msg action focus-workspace terminal && kitty";
            "Mod+D".action = spawn "walker";
            # "Mod+W".action = sh (builtins.concatStringsSep "; " [
            #   "systemctl --user restart waybar.service"
            #   "systemctl --user restart swaybg.service"
            # ]);

            "Mod+L".action = spawn "blurred-locker";
            "Print".action = sh "flameshot full --clipboard";
            "Mod+Print".action = screenshot;
            "Shift+Super+S".action = screenshot;
            # "Mod+Shift+Print".action = sh "flames /hot full";

            "XF86AudioRaiseVolume".action = sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+";
            "XF86AudioLowerVolume".action = sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-";
            "XF86AudioMute".action = sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";

            "XF86MonBrightnessUp".action = sh "brightnessctl set 10%+";
            "XF86MonBrightnessDown".action = sh "brightnessctl set 10%-";

            "Mod+Q".action = close-window;

            "XF86AudioNext".action = focus-column-right;
            "XF86AudioPrev".action = focus-column-left;

            "Mod+Tab".action = focus-window-down-or-column-right;
            "Mod+Shift+Tab".action = focus-window-up-or-column-left;
          }
          (binds {
            suffixes."Left" = "column-left";
            suffixes."Down" = "window-down";
            suffixes."Up" = "window-up";
            suffixes."Right" = "column-right";
            prefixes."Mod" = "focus";
            prefixes."Mod+Ctrl" = "move";
            prefixes."Mod+Shift" = "focus-monitor";
            prefixes."Mod+Shift+Ctrl" = "move-window-to-monitor";
            substitutions."monitor-column" = "monitor";
            substitutions."monitor-window" = "monitor";
          })
          (binds {
            suffixes."Home" = "first";
            suffixes."End" = "last";
            prefixes."Mod" = "focus-column";
            prefixes."Mod+Ctrl" = "move-column-to";
          })
          (binds {
            suffixes."U" = "workspace-down";
            suffixes."I" = "workspace-up";
            prefixes."Mod" = "focus";
            prefixes."Mod+Ctrl" = "move-window-to";
            prefixes."Mod+Shift" = "move";
          })
          (binds {
            suffixes = builtins.listToAttrs (
              map (n: {
                name = toString n;
                value = [
                  "workspace"
                  n
                ];
              }) (range 1 9)
            );
            prefixes."Mod" = "focus";
            prefixes."Mod+Ctrl" = "move-window-to";
          })
          {
            "Mod+Shift+T".action = focus-workspace "terminal";
            "Mod+E".action = spawn "nautilus";
            "Mod+Comma".action = consume-window-into-column;
            "Mod+Period".action = expel-window-from-column;

            "Mod+R".action = switch-preset-column-width;
            "Mod+F".action = maximize-column;
            "Mod+Shift+F".action = fullscreen-window;
            "Mod+C".action = center-column;

            "Mod+Minus".action = set-column-width "-10%";
            "Mod+Plus".action = set-column-width "+10%";
            "Mod+Shift+Minus".action = set-window-height "-10%";
            "Mod+Shift+Plus".action = set-window-height "+10%";

            "Mod+Shift+E".action = quit;
            "Mod+Shift+P".action = power-off-monitors;

            "Mod+Shift+Ctrl+T".action = toggle-debug-tint;
          }
        ];

      # examples:
      spawn-at-startup = [
        {
          command =
            let
              units = [
                "niri"
                "graphical-session.target"
                "xdg-desktop-portal"
                "xdg-desktop-portal-gnome"
                "waybar"
              ];
              commands = builtins.concatStringsSep ";" (map (unit: "systemctl --user status ${unit}") units);
            in
            [
              "kitty"
              "--"
              "sh"
              "-c"
              "env SYSTEMD_COLORS=1 watch -n 1 -d --color '${commands}'"
            ];
        }

        { command = [ "xwayland-satellite" ]; }
        { command = [ "swww-daemon" ]; }
      ];

      animations.shaders.window-resize = ''
        vec4 resize_color(vec3 coords_curr_geo, vec3 size_curr_geo) {
            vec3 coords_next_geo = niri_curr_geo_to_next_geo * coords_curr_geo;

            vec3 coords_stretch = niri_geo_to_tex_next * coords_curr_geo;
            vec3 coords_crop = niri_geo_to_tex_next * coords_next_geo;

            // We can crop if the current window size is smaller than the next window
            // size. One way to tell is by comparing to 1.0 the X and Y scaling
            // coefficients in the current-to-next transformation matrix.
            bool can_crop_by_x = niri_curr_geo_to_next_geo[0][0] <= 1.0;
            bool can_crop_by_y = niri_curr_geo_to_next_geo[1][1] <= 1.0;

            vec3 coords = coords_stretch;
            if (can_crop_by_x)
                coords.x = coords_crop.x;
            if (can_crop_by_y)
                coords.y = coords_crop.y;

            vec4 color = texture2D(niri_tex_next, coords.st);

            // However, when we crop, we also want to crop out anything outside the
            // current geometry. This is because the area of the shader is unspecified
            // and usually bigger than the current geometry, so if we don't fill pixels
            // outside with transparency, the texture will leak out.
            //
            // When stretching, this is not an issue because the area outside will
            // correspond to client-side decoration shadows, which are already supposed
            // to be outside.
            if (can_crop_by_x && (coords_curr_geo.x < 0.0 || 1.0 < coords_curr_geo.x))
                color = vec4(0.0);
            if (can_crop_by_y && (coords_curr_geo.y < 0.0 || 1.0 < coords_curr_geo.y))
                color = vec4(0.0);

            return color;
        }
      '';

      window-rules = [
        {
          draw-border-with-background = false;
          geometry-corner-radius =
            let
              r = 8.0;
            in
            {
              top-left = r;
              top-right = r;
              bottom-left = r;
              bottom-right = r;
            };
          clip-to-geometry = true;
        }
        {
          matches = [ { is-focused = false; } ];
          opacity = 0.95;
        }
        {
          matches = [ { app-id = "kitty"; } ];
          opacity = 0.8;
          open-maximized = true;
          open-on-workspace = "terminal";
        }
        {
          matches = [ { app-id = "zen"; } ];
          opacity = 0.97;
          open-maximized = true;
          open-on-workspace = "browser";
        }
        {
          matches = [
            {
              app-id = "^firefox$";
              title = "Private Browsing";
            }
          ];
          border.active.color = "purple";
        }
      ];
    };
  };
  programs.kitty = {
    enable = true;
    shellIntegration.enableBashIntegration = true;
    themeFile = "Nightfox";
    environment = {
      VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json";
      QT_QPA_PLATFORM = "wayland";
      DISPLAY = ":0";
      EDITOR = "nvim";
      WLR_NO_HARDWARE_CURSORS = "1";
      NIXOS_OZONE_WL = "1";
    };
  };

  services.swaync = {
    enable = true;
  };

  home.packages = with pkgs; [
    brightnessctl
    grim
    slurp
    xwayland
    xwayland-satellite-unstable
    swww
  ];
}
