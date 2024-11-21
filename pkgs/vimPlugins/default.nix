{ pkgs, ... }:
let
  inherit (pkgs) callPackage;
in
{
  format-on-save = callPackage ./format-on-save.nix { };
  magazine = callPackage ./magazine.nix { };
  remote-nvim = callPackage ./remote-nvim.nix { };
  tailwindcss-colorizer-cmp = callPackage ./tailwindcss-colorizer-cmp.nix { };
  tiny-inline-diagnostic = callPackage ./tiny-inline-diagnostic.nix { };
  workspace-diagnostics = callPackage ./workspace-diagnostics.nix { };
}
