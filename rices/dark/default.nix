{ delib, ... }:
delib.rice {
  name = "dark";

  nixos = {
    imports = [
      ({ pkgs, ... }: {
        # Vendored from tinted-theming/schemes (the same rev nixpkgs
        # packages as base16-schemes): a store *source* path, not a derivation
        # output. Pointing this at ${pkgs.base16-schemes}/... instead makes
        # every evaluation an IFD build, which breaks the moment that output
        # is garbage-collected.
        stylix.base16Scheme = ./ayu-dark.yaml;
        stylix.polarity = "dark";
        # Snowy night forest (wallhaven 95o881, uploader mpjuan06):
        # near-black left third for the vertical bar, blue/cyan canopy
        # on ayu's #0b0e14/#59c2ff spine.
        stylix.image = ./wallpaper.jpg;

        # Greeter follows this rice: dark theme, matching cursor, and the
        # fetched dark wallpaper (falls back to built-in defaults until the
        # first wallfetch lands; kept in sync at runtime by greeter-sync).
        services.displayManager.noctalia-greeter.settings = {
          appearance = {
            theme_mode = "dark";
            wallpaper = {
              path = "/var/lib/wallpapers/current-dark.jpg";
              fill_mode = "crop";
            };
          };
          cursor = {
            theme = "catppuccin-mocha-light-cursors";
            size = 24;
            path = "${pkgs.catppuccin-cursors.mochaLight}/share/icons";
          };
        };
      })
    ];
  };

  home = {
    imports = [
      ({ pkgs, ... }: {
        gtk = {
          enable = true;
          iconTheme = {
            name = "Papirus-Dark";
            package = pkgs.catppuccin-papirus-folders.override {
              flavor = "mocha";
              accent = "lavender";
            };
          };
          cursorTheme = {
            name = "Catppuccin-Mocha-Light-Cursors";
            package = pkgs.catppuccin-cursors.mochaLight;
          };
          gtk3 = {
            extraConfig.gtk-application-prefer-dark-theme = true;
          };
        };
      })
    ];
  };
}
