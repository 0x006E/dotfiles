{ pkgs, ... }:

{
  stylix = {
    enable = true;
    image = ./wallpaper.jpg;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/3024.yaml";
  };
}
