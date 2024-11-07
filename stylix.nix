{ pkgs, config, ... }:

{
  stylix = {
    enable = true;
    image = ./wallpaper.jpg;
    # base16Scheme = "${pkgs.base16-schemes}/share/themes/3024.yaml";
    fonts = {
      serif = config.stylix.fonts.monospace;
      sansSerif = config.stylix.fonts.monospace;
      emoji = config.stylix.fonts.monospace;
      monospace = {
        package = (pkgs.nerdfonts.override { fonts = [ "CommitMono" ]; });
        name = "CommitMono Nerd Font";
      };
    };
  };
}
