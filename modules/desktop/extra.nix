{ delib, inputs, ... }:
delib.module {
  name = "desktop.extra";

  nixos.always =
    { myconfig, ... }:
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      imports = [ inputs.noctalia.nixosModules.default ];
      programs.noctalia.enable = true;
      services.upower.enable = true;
      nixpkgs.overlays = import ../../overlays { inherit inputs; };
    };

  home.always =
    { myconfig, ... }:
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      imports = [
        inputs.noctalia.homeModules.default
      ];
    };
}
