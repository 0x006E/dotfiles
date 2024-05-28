{
  description = "System Configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      chaotic,
      ...
    }:
    {
      nixosConfigurations = {
        ntsv = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.nithin = import ./home.nix;
              home-manager.backupFileExtension = "bak"; # Optionally, use home-manager.extraSpecialArgs to pass
              # arguments to home.nix
            }
            chaotic.nixosModules.default
          ];
        };
      };
    };
}
