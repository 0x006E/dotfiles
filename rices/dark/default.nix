{ delib, ... }:
delib.rice {
  name = "dark";

  nixos = {
    imports = [
      ({ pkgs, ... }: {
        stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/ayu-dark.yaml";
        stylix.polarity = "dark";
        # Snowy night forest (wallhaven 95o881, uploader mpjuan06):
        # near-black left third for the vertical bar, blue/cyan canopy
        # on ayu's #0b0e14/#59c2ff spine.
        stylix.image = ./wallpaper.jpg;
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
