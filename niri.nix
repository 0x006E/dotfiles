{
  pkgs,
  config,
  lib,
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
      environment = {
        VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json";
        QT_QPA_PLATFORM = "wayland";
        DISPLAY = ":0";
        EDITOR = "nvim";
        WLR_NO_HARDWARE_CURSORS = "1";
        NIXOS_OZONE_WL = "1";
      };
      # Input Configuration
      input = {
        keyboard.xkb.layout = "us";
        focus-follows-mouse.enable = true;
        mouse.accel-speed = 1.0;
        touchpad = {
          tap = true;
          dwt = true;
          natural-scroll = true;
          click-method = "clickfinger";
        };
        tablet.map-to-output = "eDP-1";
        touch.map-to-output = "eDP-1";
      };

      # Workspace Configuration
      prefer-no-csd = true;
      workspaces = {
        terminal = { };
        browser = { };
      };

      # Layout Configuration
      layout = {
        gaps = 4;
        struts = {
          top = 0;
          bottom = 0;
          left = 0;
          right = -4;
        };
        focus-ring.enable = false;
        border = {
          enable = true;
          width = 2;
        };
      };

      hotkey-overlay.skip-at-startup = true;

      # Keybindings Configuration
      binds =
        with config.lib.niri.actions;
        let
          sh = spawn "sh" "-c";
        in
        lib.attrsets.mergeAttrsList [
          # Basic Application Controls
          {
            "Mod+T".action = sh "niri msg action focus-workspace terminal && rio";
            "Mod+D".action = spawn "walker";
            "Mod+E".action = spawn "nautilus";
            "Mod+L".action = spawn "blurred-locker";
            "Mod+Q".action = close-window;
          }

          # Screenshot Controls
          {
            "Print".action = sh "flameshot full --clipboard";
            "Mod+Print".action = screenshot;
            "Shift+Super+S".action = screenshot;
          }

          # Media Controls
          {
            "XF86AudioRaiseVolume".action = sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+";
            "XF86AudioLowerVolume".action = sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-";
            "XF86AudioMute".action = sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
            "XF86MonBrightnessUp".action = sh "brightnessctl set 10%+";
            "XF86MonBrightnessDown".action = sh "brightnessctl set 10%-";
            "XF86AudioNext".action = focus-column-right;
            "XF86AudioPrev".action = focus-column-left;
          }

          # Window Navigation
          {
            "Mod+Tab".action = focus-window-down-or-column-right;
            "Mod+Shift+Tab".action = focus-window-up-or-column-left;
          }

          # Directional Controls
          (binds {
            suffixes = {
              "Left" = "column-left";
              "Down" = "window-down";
              "Up" = "window-up";
              "Right" = "column-right";
            };
            prefixes = {
              "Mod" = "focus";
              "Mod+Ctrl" = "move";
              "Mod+Shift" = "focus-monitor";
              "Mod+Shift+Ctrl" = "move-window-to-monitor";
            };
            substitutions = {
              "monitor-column" = "monitor";
              "monitor-window" = "monitor";
            };
          })

          # Column Navigation
          (binds {
            suffixes = {
              "Home" = "first";
              "End" = "last";
            };
            prefixes = {
              "Mod" = "focus-column";
              "Mod+Ctrl" = "move-column-to";
            };
          })

          # Workspace Navigation
          (binds {
            suffixes = {
              "U" = "workspace-down";
              "I" = "workspace-up";
            };
            prefixes = {
              "Mod" = "focus";
              "Mod+Ctrl" = "move-window-to";
              "Mod+Shift" = "move";
            };
          })

          # Workspace Number Bindings
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
            prefixes = {
              "Mod" = "focus";
              "Mod+Ctrl" = "move-window-to";
            };
          })

          # Window Management
          {
            "Mod+Shift+T".action = focus-workspace "terminal";
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

      # Startup Applications
      spawn-at-startup = [
        { command = [ "xwayland-satellite" ]; }
        { command = [ "sleep 5; unset DISPLAY; waybar" ]; }
        { command = [ "swww-daemon" ]; }
        { command = [ "sleep 1; swww img ${./wallpaper.jpg} -t wipe" ]; }
      ];

      # Animations
      animations.shaders.window-resize = ''
        vec4 resize_color(vec3 coords_curr_geo, vec3 size_curr_geo) {
            vec3 coords_next_geo = niri_curr_geo_to_next_geo * coords_curr_geo;

            vec3 coords_stretch = niri_geo_to_tex_next * coords_curr_geo;
            vec3 coords_crop = niri_geo_to_tex_next * coords_next_geo;

            bool can_crop_by_x = niri_curr_geo_to_next_geo[0][0] <= 1.0;
            bool can_crop_by_y = niri_curr_geo_to_next_geo[1][1] <= 1.0;

            vec3 coords = coords_stretch;
            if (can_crop_by_x)
                coords.x = coords_crop.x;
            if (can_crop_by_y)
                coords.y = coords_crop.y;

            vec4 color = texture2D(niri_tex_next, coords.st);

            if (can_crop_by_x && (coords_curr_geo.x < 0.0 || 1.0 < coords_curr_geo.x))
                color = vec4(0.0);
            if (can_crop_by_y && (coords_curr_geo.y < 0.0 || 1.0 < coords_curr_geo.y))
                color = vec4(0.0);

            return color;
        }
      '';

      # Window Rules
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
          matches = [ { app-id = "rio"; } ];
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

  programs.zellij.enable = true;
  programs.rio = {
    enable = true;
    settings = {
      window = {
        foreground-opacity = 1.0;
        background-opacity = 0.96;
        blur = true;
        decorations = "Disabled";
        mode = "Maximized";
      };
      env-vars = [
        "TERM=xterm-256color"
        "COLORTERM=truecolor"
        "WINIT_X11_SCALE_FACTOR=1"
      ];
      fonts = {
        family = config.stylix.fonts.monospace.name;
        size = 16;
      };
      navigation = {
        mode = "Plain";
      };
      shell = {
        program = "${lib.makeBinPath [ config.programs.zellij.package ]}/zellij";
        args = [
          "-l "
          ./layout.kdl
        ];
      };
    };
  };
  services.swaync.enable = true;

  home.packages = with pkgs; [
    brightnessctl
    grim
    slurp
    xwayland
    xwayland-satellite-unstable
    swww
  ];
}
