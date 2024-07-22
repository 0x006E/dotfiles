{
  description = "System Configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-23.11";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    alejandra.url = "github:kamadorueda/alejandra/3.0.0";
    alejandra.inputs.nixpkgs.follows = "nixpkgs";
    nil.url = "github:oxalica/nil";
    niri.url = "github:sodiboo/niri-flake";
    ags.url = "github:Aylur/ags";
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.1";

      # Optional but recommended to limit the size of your system closure.
      inputs.nixpkgs.follows = "nixpkgs";
    };
    walker.url = "github:abenz1267/walker";
  };

  outputs = {
    alejandra,
    nixpkgs,
    nixpkgs-stable,
    home-manager,
    chaotic,
    lanzaboote,
    niri,
    ags,
    walker,
    ...
  } @ inputs: {
    nixosConfigurations = {
      ntsv = nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";
        specialArgs = {
          pkgs-stable = import nixpkgs-stable {
            inherit system;
            config.allowUnfree = true;
          };
          inherit inputs;
        };
        modules = [
          niri.nixosModules.niri
          {
            environment.systemPackages = [alejandra.defaultPackage.${system}];
          }
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.extraSpecialArgs = {inherit inputs;};
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
