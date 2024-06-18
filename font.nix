  fonts = {
    fontconfig = {
      # ultimate.enable = true; # This enables fontconfig-ultimate settings for better font rendering
      defaultFonts = {
        monospace = ["Iosevka"];
      };
    };
    enableFontDir = true;
    enableGhostscriptFonts = true;
    fonts = with pkgs; [
      terminus_font      corefonts
     noto-fonts
     iosevka
   ];
 };
