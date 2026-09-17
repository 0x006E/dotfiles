{ delib, ... }:
delib.rice {
  name = "light";

  nixos = {
    imports = [
      ({ pkgs, ... }: {
        stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-latte.yaml";
        stylix.polarity = "light";
        stylix.image = ./wallpaper.jpg;

        # Greeter follows this rice: light theme, matching cursor, and the
        # fetched light wallpaper (see rices/dark for the fallback story).
        services.displayManager.noctalia-greeter.settings = {
          appearance = {
            theme_mode = "light";
            wallpaper = {
              path = "/var/lib/wallpapers/current-light.jpg";
              fill_mode = "crop";
            };
          };
          cursor = {
            theme = "catppuccin-latte-dark-cursors";
            size = 24;
            path = "${pkgs.catppuccin-cursors.latteDark}/share/icons";
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
            name = "Papirus-Light";
            package = pkgs.catppuccin-papirus-folders.override {
              flavor = "latte";
              accent = "lavender";
            };
          };
          cursorTheme = {
            name = "Catppuccin-Latte-Dark-Cursors";
            package = pkgs.catppuccin-cursors.latteDark;
          };
          gtk3 = {
            extraConfig.gtk-application-prefer-dark-theme = false;
          };
        };
      })
    ];
  };
}
