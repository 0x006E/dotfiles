# Returns a list of nixpkgs overlays. Consumed by:
#   - modules/desktop/extra.nix   -> nixpkgs.overlays
#   - flake.nix                   -> standalone pkgs for the CI packages matrix
{ inputs }:
[
  inputs.niri.overlays.niri
  inputs.nix-vscode-extensions.overlays.default

  # Custom packages from pkgs/ (boomaga, vim plugins).
  (final: prev: import ../pkgs { pkgs = prev; })

  # Targeted fixes and additions on top of nixpkgs.
  (
    final: prev: {
      python3 = prev.python3.override {
        packageOverrides = pfinal: pprev: {
          curl-cffi = pprev.curl-cffi.overridePythonAttrs (_: {
            doCheck = false;
          });
        };
      };
      python3Packages = final.python3.pkgs;
      vimPlugins = prev.vimPlugins // import ../pkgs/vimPlugins { pkgs = final; };
      mpv = prev.mpv.override {
        scripts = [ final.mpvScripts.mpris ];
      };
      qgnomeplatform = prev.qgnomeplatform.overrideAttrs (old: {
        cmakeFlags = old.cmakeFlags or [ ] ++ [ "-DCMAKE_POLICY_VERSION_MINIMUM=3.5" ];
      });
    }
  )
]
