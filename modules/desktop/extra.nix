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
      imports = [
        inputs.noctalia.nixosModules.default
        ../../overlays/default.nix
      ];
      programs.noctalia.enable = true;
      services.upower.enable = true;
      nixpkgs.overlays = [
        inputs.nix-vscode-extensions.overlays.default
      ];
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
