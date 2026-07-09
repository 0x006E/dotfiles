{ delib, inputs, ... }:
delib.module {
  name = "core.nix";

  nixos.always =
    { myconfig, ... }:
    {
      pkgs,
      config,
      lib,
      pkgs-stable,
      pkgs-unstable,
      ...
    }:
    {
      imports = [
        inputs.determinate.nixosModules.default
        inputs.nix-index-database.nixosModules.nix-index
      ];
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {
          inherit inputs pkgs-stable pkgs-unstable;
        };
      };
      nix = {
        nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
        extraOptions = ''
          experimental-features = nix-command flakes parallel-eval
        '';
        daemonCPUSchedPolicy = "idle";
        daemonIOSchedClass = "idle";
        settings = {
          auto-optimise-store = true;
          max-jobs = 4;
          cores = 4;
          trusted-users = [
            "root"
            "@wheel"
          ];
          substituters = [
            "https://lanzaboote.cachix.org"
            "https://0x006e-nix.cachix.org"
            "https://noctalia.cachix.org"
          ];
          trusted-public-keys = [
            "lanzaboote.cachix.org-1:Nt9//zGmqkg1k5iu+B3bkj3OmHKjSw9pvf3faffLLNk="
            "0x006e-nix.cachix.org-1:JV0ESHZ7I9+ihTkFJ81RtqsjzV/2845VPwpU8OD8JL8="
            "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
          ];
        };
      };

      nixpkgs = {
        config.allowUnfree = true;
      };

      environment.etc."nix/nix.custom.conf".text = ''
        eval-cores = 4
      '';
    };
}
