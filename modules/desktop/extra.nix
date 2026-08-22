{ delib, inputs, ... }:
delib.module {
  name = "desktop.extra";

  nixos.always =
    { ... }:
    {
      ...
    }:
    {
      imports = [ inputs.noctalia.nixosModules.default ];
      programs.noctalia.enable = true;
      services.upower.enable = true;
      nixpkgs.overlays = import ../../overlays { inherit inputs; };
    };

  home.always =
    { ... }:
    {
      ...
    }:
    {
      imports = [
        inputs.noctalia.homeModules.default
      ];
    };
}
