{ pkgs, ... }:
{
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
          "CommitMono Nerd Font"
        ];
      };
    };
    fontDir.enable = true;
    enableGhostscriptFonts = true;
    packages = with pkgs; [
      terminus_font
      font-awesome
      powerline-fonts
      corefonts
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      nerd-fonts.commit-mono
      liberation_ttf
      fira-code
      fira-code-symbols
      mplus-outline-fonts.githubRelease
    ];
  };
}
