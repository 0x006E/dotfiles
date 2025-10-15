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
      debug = {
        honor-xdg-activation-with-invalid-serial = true;
        render-drm-device = "/dev/dri/renderD128";
      };
      environment = {
        VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json";
        QT_QPA_PLATFORM = "wayland";
        DISPLAY = ":12";
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
            "Mod+T".action = sh "niri msg action focus-workspace terminal && ghostty";
            "Mod+D".action = spawn "noctalia-shell" "ipc" "call" "launcher" "toggle";
            "Mod+E".action = spawn "nautilus";
            "Mod+L".action =
              sh ''notify-send "Locking Screen" "Your screen is being locked." --icon=system-lock-screen && noctalia-shell ipc call lockScreen toggle '';
            "Mod+Shift+L".action =
              sh ''notify-send "Suspending Device" "System will suspend now." --icon=system-suspend && systemctl suspend'';
            "Mod+Q".action = close-window;
            "Mod+V".action = spawn "noctalia-shell" "ipc" "call" "launcher" "clipboard";
          }

          # Screenshot Controls
          {
            "Print".action = sh "flameshot full --clipboard";
            "Mod+Print".action = screenshot;
            "Shift+Super+S".action = screenshot;
          }

          # Media Controls
          {
            "XF86AudioRaiseVolume".action = sh "noctalia-shell ipc call volume increase";
            "XF86AudioLowerVolume".action = sh "noctalia-shell ipc call volume decrease";
            "XF86AudioMute".action = sh "noctalia-shell ipc call volume muteOutput";

            "XF86MonBrightnessUp".action = sh "noctalia-shell ipc call brightness increase";
            "XF86MonBrightnessDown".action = sh "noctalia-shell ipc call brightness decrease";
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
            "Mod+Shift+Z".action = focus-workspace "zen";
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
        {
          command = [
            "${lib.makeBinPath [ pkgs.xwayland-satellite-unstable ]}/xwayland-satellite"
            ":12"
          ];
        }
        # { command = [ "sleep 5; systemctl --user reset-failed waybar.service" ]; }
        { command = [ "systemctl --user reset-failed niri-flake-polkit.service" ]; }
        # { command = [ "swww-daemon" ]; }
        { command = [ "dex" ]; }
        # { command = [ "sleep 1; swww img ${./wallpaper.jpg} -t wipe" ]; }
      ];

      layer-rules = [
        {
          matches = [ { namespace = "^quickshell-overview$"; } ];
          place-within-backdrop = true;
        }
      ];

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
          matches = [ { app-id = "ghostty"; } ];
          opacity = 0.9;
          open-maximized = true;
          open-on-workspace = "terminal";
        }
        {
          matches = [ { app-id = "zen"; } ];
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
        }
      ];
    };
  };

  programs.ghostty = {
    enable = true;
    enableBashIntegration = true;
    installVimSyntax = true;
  };
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # after_sleep_cmd = "hyprctl dispatch dpms on";
        ignore_dbus_inhibit = false;
        lock_cmd = "noctalia-shell ipc call lockScreen toggle";
        before_sleep_cmd = "noctalia-shell ipc call lockScreen toggle";
      };
      listener = [
        {
          timeout = 300;
          on-timeout = "noctalia-shell ipc call lockScreen toggle";
        }
        {
          timeout = 600;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };

  home.packages = with pkgs; [
    dex
    brightnessctl
    cliphist
    grim
    slurp
    xwayland-satellite-unstable
  ];
}
