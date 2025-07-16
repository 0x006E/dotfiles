{
  description = "Nithin's NixOS Configuration";

  inputs = {
    # Core Nixpkgs
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable-small";
    nixpkgs-stable.url = "https://flakehub.com/f/NixOS/nixpkgs/*";
    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Desktop and UI
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Development Tools
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # System Management
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    walker = {
      url = "github:abenz1267/walker";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    erosanix.url = "github:emmanuelrosa/erosanix"; # Utilities
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    battery-notifier = {
      url = "github:luisnquin/battery-notifier";
    };
    nix-github-actions = {
      url = "github:nix-community/nix-github-actions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      nixpkgs-unstable,
      nix-index-database,
      nix-github-actions,
      home-manager,
      chaotic,
      battery-notifier,
      lanzaboote,
      niri,
      stylix,
      erosanix,
      nix-flatpak,
      determinate,

      ...
    }@inputs:
    let
      system = "x86_64-linux";

      # Package Sets
      pkgs-stable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };

      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

    in
    {
      packages.${system} = import ./pkgs {
        inherit
          nixpkgs
          pkgs-stable
          pkgs-unstable
          inputs
          system
          ;

        pkgs = nixpkgs.legacyPackages.${system};
      };

      githubActions = nix-github-actions.lib.mkGithubMatrix { checks = self.packages; };
      nixosConfigurations = {

        ntsv = nixpkgs.lib.nixosSystem {
          inherit system;

          # Special Arguments
          specialArgs = {
            inherit
              inputs
              pkgs-stable
              pkgs-unstable
              self
              system
              ;
          };

          modules = [
            # Core Modules
            stylix.nixosModules.stylix
            battery-notifier.nixosModules.default
            erosanix.nixosModules.protonvpn
            niri.nixosModules.niri
            ./overlays
            # Overlays
            {
              nixpkgs.overlays = [
                inputs.nix-vscode-extensions.overlays.default
              ];
            }

            # Configuration
            ./configuration.nix

            # Home Manager
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "bak";

                extraSpecialArgs = {
                  inherit inputs pkgs-unstable pkgs-stable;
                };

                users.nithin = import ./home.nix;
              };
            }

            # Additional Modules
            nix-index-database.nixosModules.nix-index
            chaotic.nixosModules.default
            lanzaboote.nixosModules.lanzaboote
            ./secureboot.nix
            determinate.nixosModules.default
            nix-flatpak.nixosModules.nix-flatpak
          ];
        };
      };

      # Formatter Configuration
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
    };
}
