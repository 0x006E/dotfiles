{
  pkgs,
  inputs,
  system,
  ...
}:
let
  inherit (pkgs) callPackage libsForQt5;
  customVimPlugins = import ./vimPlugins { inherit pkgs; };
in
rec {
  libfprint = callPackage ./libfprint { };
  boomaga = libsForQt5.callPackage ./boomaga.nix { };
  zoho-mail = callPackage ./zoho-mail.nix { };
  fprintd = callPackage ./fprintd.nix { libfprint = libfprint; };
  ignis = callPackage ./ignis.nix { };
  zen-browser-unwrapped = inputs.zen-browser.packages."${system}".beta-unwrapped;
  zen-browser-bin = inputs.zen-browser.packages."${system}".beta;
}
// customVimPlugins
