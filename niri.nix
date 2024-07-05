{
  pkgs,
  config,
  ...
}: {
  programs.niri = {
    settings = {
      input.keyboard.xkb.layout = "no";
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
        gaps = 16;
        struts.left = 64;
        struts.right = 64;
        border.width = 4;
      };

      hotkey-overlay.skip-at-startup = true;

      binds = with config.lib.niri.actions; let
        sh = spawn "sh" "-c";

        screenshot-area-script = pkgs.writeShellScript "screenshot-area" ''
          grim -o $(niri msg --json focused-output | jq -r .name) - | swayimg --config=info.mode=off --fullscreen - &
          SWAYIMG=$!
          niri msg action do-screen-transition -d 1200
          sleep 1.2
          grim -g "$(slurp)" - | wl-copy -t image/png
          niri msg action do-screen-transition
          kill $SWAYIMG
        '';

        screenshot-area = spawn "${screenshot-area-script}";
      in
        lib.attrsets.mergeAttrsList [
          {
            "Mod+T".action = spawn "foot";
            "Mod+D".action = spawn "fuzzel";
            "Mod+W".action = sh (builtins.concatStringsSep "; " [
              "systemctl --user restart waybar.service"
              "systemctl --user restart swaybg.service"
            ]);

            "Mod+L".action = spawn "blurred-locker";
            "Mod+Shift+S".action = screenshot-area;
            "Mod+Print".action = screenshot-window;

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
            suffixes = builtins.listToAttrs (map (n: {
              name = toString n;
              value = ["workspace" n];
            }) (range 1 9));
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

      # spawn-at-startup = [
      #   {command = ["alacritty"];}
      #   {command = ["waybar"];}
      #   {command = ["swww" "start"];}
      # ];

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
          geometry-corner-radius = let
            r = 8.0;
          in {
            top-left = r;
            top-right = r;
            bottom-left = r;
            bottom-right = r;
          };
          clip-to-geometry = true;
        }
        {
          matches = [{is-focused = false;}];
          opacity = 0.95;
        }
        {
          # the terminal is already transparent from stylix
          matches = [{app-id = "^foot$";}];
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

  programs.foot = {
    enable = true;
    settings.csd.preferred = "none";
  };

  programs.fuzzel = {
    enable = true;
    settings.main.terminal = "foot";
  };
  services.swaync = {
    enable = true;
  };
}
