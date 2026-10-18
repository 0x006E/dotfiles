# Returns a list of nixpkgs overlays. Consumed by:
#   - modules/desktop/extra.nix   -> nixpkgs.overlays
#   - flake.nix                   -> standalone pkgs for the CI packages matrix
{ inputs }:
[
  inputs.niri.overlays.niri
  inputs.nix-vscode-extensions.overlays.default

  # Custom packages from pkgs/ (boomaga, vim plugins).
  (_final: prev: import ../pkgs { pkgs = prev; })

  # Targeted fixes and additions on top of nixpkgs.
  (final: prev: {
    vimPlugins = prev.vimPlugins // import ../pkgs/vimPlugins { pkgs = final; };
    mpv = prev.mpv.override {
      scripts = [ final.mpvScripts.mpris ];
    };
  })
]
