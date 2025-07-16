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
}
// customVimPlugins
