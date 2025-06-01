{
  pkgs,
  inputs,
  system,
  ...
}:
let
  inherit (pkgs) libsForQt5;
  customVimPlugins = import ./vimPlugins { inherit pkgs; };
in
{
  boomaga = libsForQt5.callPackage ./boomaga.nix { };
  zen-browser-unwrapped = inputs.zen-browser.packages."${system}".beta-unwrapped;
  zen-browser-bin = inputs.zen-browser.packages."${system}".beta;
}
// customVimPlugins
