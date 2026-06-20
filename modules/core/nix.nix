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
        settings = {
          auto-optimise-store = true;
          trusted-users = [
            "root"
            "@wheel"
          ];
          substituters = [
            "https://lanzaboote.cachix.org"
            "https://cache.garnix.io"
            "https://0x006e-nix.cachix.org"
          ];
          trusted-public-keys = [
            "lanzaboote.cachix.org-1:Nt9//zGmqkg1k5iu+B3bkj3OmHKjSw9pvf3faffLLNk="
            "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
            "0x006e-nix.cachix.org-1:JV0ESHZ7I9+ihTkFJ81RtqsjzV/2845VPwpU8OD8JL8="
          ];
        };
      };

      nixpkgs = {
        config.allowUnfree = true;
      };

      environment.etc."nix/nix.custom.conf".text = ''
        eval-cores = 0
      '';
    };
}
