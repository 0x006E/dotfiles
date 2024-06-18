{pkgs, ...}: {
  # nixpkgs.config = {
  #   packageOverrides = pkgs: {
  #     iosevka-term = pkgs.iosevka.override {
  #       variant = "sgr-iosevka-term-ss11";
  #     };
  #   };
  # };
  fonts = {
    fontconfig = {
      # ultimate.enable = true; # This enables fontconfig-ultimate settings for better font rendering
      defaultFonts = {monospace = ["Iosevka"];};
    };
    fontDir.enable = true;
    enableGhostscriptFonts = true;
    packages = with pkgs; [terminus_font corefonts noto-fonts iosevka-bin];
  };
}
