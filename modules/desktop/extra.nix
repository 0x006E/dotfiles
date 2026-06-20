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
      services.noctalia-shell.enable = true;
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
