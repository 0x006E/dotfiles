{ pkgs, ... }:
let
  inherit (pkgs) callPackage;
in
{
  format-on-save = callPackage ./format-on-save.nix { };
  signup-nvim = callPackage ./signup-nvim.nix { };
  workspace-diagnostics = callPackage ./workspace-diagnostics.nix { };
}
