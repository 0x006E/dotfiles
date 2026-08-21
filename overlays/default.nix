{
  system,
  pkgs,
  inputs,
  ...
}:
let
  customVimPlugins = import ../pkgs/vimPlugins { inherit pkgs; };
in
{
  nixpkgs.overlays = [
    inputs.niri.overlays.niri
    inputs.nix-vscode-extensions.overlays.default
    (
      final: prev:
      import ../pkgs {
        inherit inputs system;
        pkgs = prev;
      }
    )
    (final: prev: {
      python3 = prev.python3.override {
        packageOverrides = pfinal: pprev: {
          curl-cffi = pprev.curl-cffi.overridePythonAttrs (_: {
            doCheck = false;
          });
        };
      };
      python3Packages = final.python3.pkgs;
      vimPlugins = prev.vimPlugins // customVimPlugins;
      mpv = prev.mpv.override {
        scripts = [ final.mpvScripts.mpris ];
      };
      qgnomeplatform = prev.qgnomeplatform.overrideAttrs (old: {
        cmakeFlags = old.cmakeFlags or [ ] ++ [ "-DCMAKE_POLICY_VERSION_MINIMUM=3.5" ];
      });
    })
  ];
}
