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

    # udiskie 2.7.0's pytest suite fails on Python 3.14:
    # TestPasswordCache::test_is_valid reads the build sandbox's real
    # process keyring, whose bytes aren't a multiple of the array item
    # size (upstream test bug, unfixed in nixpkgs as of 2026-10-22).
    # Drop this override once nixpkgs ships a fixed udiskie.
    udiskie = prev.udiskie.overridePythonAttrs (_old: {
      doCheck = false;
    });
  })
]
