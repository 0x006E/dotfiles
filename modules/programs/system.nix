{ delib, ... }:
delib.module {
  name = "programs.system";

  nixos.always =
    { myconfig, ... }:
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      programs = {
        corectrl.enable = true;
        nix-index-database.comma.enable = true;

        nix-index = {
          enable = true;
          enableBashIntegration = true;
        };

        nh = {
          enable = true;
          clean = {
            enable = true;
            extraArgs = "--keep-since 3d --keep 3";
          };
          flake = "/home/nithin/nix/denix-flake";
        };
      };
    };
}
