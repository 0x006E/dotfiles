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
          screenshot = sh ''((! pidof slurp) || sudo kill -9 $(pidof slurp)) && (grim -g "$(slurp)" - | wl-copy)'';
        in
        lib.attrsets.mergeAttrsList [
          {
            "Mod+T".action = spawn "wezterm";
            "Mod+D".action = spawn "walker";
            # "Mod+W".action = sh (builtins.concatStringsSep "; " [
            #   "systemctl --user restart waybar.service"
            #   "systemctl --user restart swaybg.service"
            # ]);

            "Mod+L".action = spawn "blurred-locker";
            "Print".action = sh "flameshot full --clipboard";
            "Mod+Print".action = sh "flameshot gui";
            "Shift+Super+S".action = sh "flameshot gui";
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
        { command = [ "xwayland-satellite" ]; }
        { command = [ "systemctl --user reset-failed waybar.service" ]; }
        { command = [ "swaybg" ]; }
        { command = [ "variety" ]; }
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
          # the terminal is already transparent from stylix
          matches = [ { app-id = "^foot$"; } ];
          opacity = 1.0;
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
  programs.wezterm = {
    enable = true;
    enableBashIntegration = true;
    extraConfig = ''
      local mux = wezterm.mux
      wezterm.on("gui-startup", function()
          local tab, pane, window = mux.spawn_window{}
          window:gui_window():maximize()
      end)
      return {
             font = wezterm.font_with_fallback {"Commit Mono", "Font Awesome 6 Free"},
             colors = {
               foreground = "#ffffff",
               background = "#16181a",
               cursor_bg = "#ffffff",
               cursor_fg = "#16181a",
               cursor_border = "#ffffff",
               selection_fg = "#ffffff",
               selection_bg = "#3c4048",

               scrollbar_thumb = "#16181a",
               split = "#16181a",

               ansi = { "#16181a", "#ff6e5e", "#5eff6c", "#f1ff5e", "#5ea1ff", "#bd5eff", "#5ef1ff", "#ffffff" },
               brights = { "#3c4048", "#ff6e5e", "#5eff6c", "#f1ff5e", "#5ea1ff", "#bd5eff", "#5ef1ff", "#ffffff" },
               indexed = { [16] = "#ffbd5e", [17] = "#ff6e5e" },
             },
             window_background_opacity = 0.95,
      }
    '';
    package = inputs.wezterm-flake.packages.${pkgs.system}.default;
  };
  programs.foot = {
    enable = true;
    settings = {
      environment = {
        VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json";
        QT_QPA_PLATFORM = "wayland";
        DISPLAY = ":0";
        EDITOR = "nvim";
        WLR_NO_HARDWARE_CURSORS = "1";
        NIXOS_OZONE_WL = "1";
      };
      csd.preferred = "none";
      main =
        let
          withSize = "size=${toString size}";
          size = "11";
          font = "Iosevka Term";
        in
        {
          term = "xterm-256color";
          font = "${font}:${withSize}";
          font-bold = "${font}:style=Bold:${withSize}";
          font-italic = "${font}:style=Italic:${withSize}";
          font-bold-italic = "${font}:style=BoldItalic:${withSize}";
          box-drawings-uses-font-glyphs = true;
          initial-window-size-pixels = "800x600";
        };

      scrollback = {
        lines = 10000;
      };

      url = {
        launch = "xdg-open \${url}";
        protocols = "http, https, ftp, ftps, file";
      };

      colors = {
        alpha = 0.75;
        foreground = "ADEFD1";
        background = "00203F";
      };
    };
  };

  programs.fuzzel = {
    enable = true;
    settings.main.terminal = "foot";
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
    variety
    swaybg
  ];
}
