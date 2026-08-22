{ delib, pkgs, ... }:
delib.module {
  name = "desktop.fonts";
  options = delib.singleEnableOption true;

  nixos.ifEnabled = { ... }: {
    fonts = {
      fontconfig = {
        defaultFonts = {
          monospace = [ "CommitMono Nerd Font" ];
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
        noto-fonts-color-emoji
        nerd-fonts.commit-mono
        liberation_ttf
        fira-code
        fira-code-symbols
        mplus-outline-fonts.githubRelease
      ];
    };
  };
}
