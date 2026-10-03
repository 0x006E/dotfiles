{ delib, ... }:
delib.rice {
  name = "light";

  nixos = {
    imports = [
      ({ pkgs, ... }: {
        # Vendored, same as the dark rice: see rices/dark/default.nix for why
        # this is a file in the repo rather than ${pkgs.base16-schemes}/...
        stylix.base16Scheme = ./catppuccin-latte.yaml;
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
