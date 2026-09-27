{ delib, inputs, ... }:
delib.module {
  name = "core.nix";

  nixos.always =
    { ... }:
    {
      pkgs-stable,
      pkgs-small,
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
          inherit inputs pkgs-stable pkgs-small;
        };
      };
      nix = {
        nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
        extraOptions = ''
          experimental-features = nix-command flakes parallel-eval
        '';
        # "idle" maps to SCHED_IDLE, which starved the substituter on a busy
        # desktop — a single nar trickled at ~50 KB/s against a 3.9 MB/s link.
        # "batch" still yields to interactive work without demoting nix below
        # every other process on the box.
        daemonCPUSchedPolicy = "batch";
        daemonIOSchedClass = "idle";
        settings = {
          auto-optimise-store = true;
          # Nix defaults to a 1 MiB download buffer, which on top of an
          # idle-priority daemon pinned a 50 MB nixpkgs source to ~50 KB/s.
          # 128 MiB keeps the nar pipeline saturated.
          download-buffer-size = 134217728;
          # Default 300s: any stall threw the whole nar away and restarted
          # from zero, so a large source could never finish. 0 disables it.
          stalled-download-timeout = 0;
          max-jobs = 4;
          cores = 4;
          trusted-users = [
            "root"
            "@wheel"
          ];
          substituters = [
            "https://install.determinate.systems"
            "https://lanzaboote.cachix.org"
            "https://0x006e-nix.cachix.org"
            "https://noctalia.cachix.org"
            "https://nix-community.cachix.org"
          ];
          trusted-public-keys = [
            "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
            "lanzaboote.cachix.org-1:Nt9//zGmqkg1k5iu+B3bkj3OmHKjSw9pvf3faffLLNk="
            "0x006e-nix.cachix.org-1:JV0ESHZ7I9+ihTkFJ81RtqsjzV/2845VPwpU8OD8JL8="
            "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
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
