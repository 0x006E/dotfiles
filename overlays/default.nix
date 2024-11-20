{
  self,
  system,
  ...
}:
let
  flakePackagesForSystem = self.packages.${system};
in
{
  nixpkgs.overlays = [
    (final: prev: flakePackagesForSystem)
    (final: prev: {

      mpv = prev.mpv.override {
        scripts = [ final.mpvScripts.mpris ];
      };
    })

  ];
}
