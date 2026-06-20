{ delib, ... }:
delib.rice {
  name = "light";

  nixos = {
    imports = [
      (
        { pkgs, ... }:
        {
          stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-latte.yaml";
          stylix.polarity = "light";
          stylix.image = ./wallpaper.jpg;
        }
      )
    ];
  };

  home = {
    imports = [
      (
        { pkgs, ... }:
        {
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
        }
      )
    ];
  };
}
