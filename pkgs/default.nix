{
  pkgs,
  nixpkgs,
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
  conky-wayland = callPackage ./conky-wayland.nix { };
  zoho-mail = callPackage ./zoho-mail.nix { };
  fprintd = callPackage ./fprintd.nix { libfprint = libfprint; };
  windsurf = callPackage ./windsurf.nix { inherit nixpkgs; };
  ignis = callPackage ./ignis.nix { };
  zen-browser-unwrapped = callPackage ./zen-browser-unwrapped { };
  zen-browser-bin = pkgs.wrapFirefox zen-browser-unwrapped { };
}
// customVimPlugins
