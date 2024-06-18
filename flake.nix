{
  description = "System Configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    alejandra.url = "github:kamadorueda/alejandra/3.0.0";
    alejandra.inputs.nixpkgs.follows = "nixpkgs";
    nil.url = "github:oxalica/nil";
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.1";

      # Optional but recommended to limit the size of your system closure.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    alejandra,
    nixpkgs,
    home-manager,
    chaotic,
    lanzaboote,
    ...
  }: {
    nixosConfigurations = {
      ntsv = nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";
        modules = [
          {
            environment.systemPackages = [alejandra.defaultPackage.${system}];
          }
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
          lanzaboote.nixosModules.lanzaboote
          ./secureboot.nix
        ];
      };
    };
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;
  };
}
