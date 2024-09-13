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
      defaultFonts = {
        monospace = [
          "Iosevka"
          "Commit Mono"
        ];
      };
    };
    fontDir.enable = true;
    enableGhostscriptFonts = true;
    packages = with pkgs; [
      terminus_font
      corefonts
      noto-fonts
      iosevka-bin
      commit-mono
    ];
  };
}
