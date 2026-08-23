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
      packages = with pkgs; [
        font-awesome
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
        nerd-fonts.commit-mono
        liberation_ttf
      ];
    };
  };
}
