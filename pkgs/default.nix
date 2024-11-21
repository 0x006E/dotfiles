{
  pkgs,
  nixpkgs,
  ...
}:
let
  inherit (pkgs) callPackage libsForQt5;
in
rec {
  libfprint = callPackage ./libfprint { };
  boomaga = libsForQt5.callPackage ./boomaga.nix { };
  conky-wayland = callPackage ./conky-wayland.nix { };
  zoho-mail = callPackage ./zoho-mail.nix { };
  fprintd = callPackage ./fprintd.nix { libfprint = libfprint; };
  windsurf = callPackage ./windsurf.nix { inherit nixpkgs; };
}
