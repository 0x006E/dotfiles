{
  pkgs,
  ...
}:
let
  customVimPlugins = import ./vimPlugins { inherit pkgs; };
in
{
  boomaga = pkgs.qt6.callPackage ./boomaga.nix { };
  wallfetch = pkgs.callPackage ./wallfetch { };
  nuvio = pkgs.callPackage ./nuvio {
    jdk21 = pkgs.jetbrains.jdk-21;
    jdk17 = pkgs.temurin-bin-17;
  };
}
// customVimPlugins
