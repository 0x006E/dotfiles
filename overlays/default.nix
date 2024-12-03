{
  self,
  system,
  pkgs,
  ...
}:
let
  flakePackagesForSystem = self.packages.${system};
  customVimPlugins = import ../pkgs/vimPlugins { inherit pkgs; };
in
{
  nixpkgs.overlays = [
    (final: prev: flakePackagesForSystem)
    (final: prev: {
      vimPlugins = prev.vimPlugins // customVimPlugins;
      mpv = prev.mpv.override {
        scripts = [ final.mpvScripts.mpris ];
      };
    })

  ];
}
