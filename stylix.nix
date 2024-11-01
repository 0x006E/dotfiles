{ pkgs, config, ... }:

{
  stylix = {
    enable = true;
    image = config.lib.stylix.pixel "base0A";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
  };
}
