{
  pkgs,
  ...
}:
let
  inherit (pkgs) libsForQt5;
  customVimPlugins = import ./vimPlugins { inherit pkgs; };
in
{
  boomaga = libsForQt5.callPackage ./boomaga.nix { };
  rice-toggle = pkgs.callPackage ./rice-toggle { };
  wallfetch = pkgs.callPackage ./wallfetch { };
  nuvio = pkgs.callPackage ./nuvio {
    jdk21 = pkgs.jetbrains.jdk-21;
    jdk17 = pkgs.temurin-bin-17;
  };
}
// customVimPlugins
