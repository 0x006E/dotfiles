{
  description = "Nithin's NixOS Configuration";

  inputs = {
    # Core Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable-small";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    # Custom Nixpkgs Forks
    nixpkgs-zen-mr.url = "github:nixos/nixpkgs/refs/pull/347222/merge";
    nixpkgs-responsively-mr.url = "github:nixos/nixpkgs/refs/pull/307444/merge";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Desktop and UI
    stylix.url = "github:danth/stylix";
    niri.url = "github:sodiboo/niri-flake";

    # Development Tools
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rio-term = {
      url = "github:raphamorim/rio";
    };
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    blink-cmp.url = "github:Saghen/blink.cmp";

    # System Management
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    walker.url = "github:abenz1267/walker";

    # Utilities
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.91.1-1.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      nixpkgs-unstable,
      nixpkgs-master,
      nixpkgs-zen-mr,
      nixpkgs-responsively-mr,
      home-manager,
      chaotic,
      lanzaboote,
      niri,
      lix-module,
      stylix,
      rio-term,
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

      pkgs-master = import nixpkgs-master {
        inherit system;
        config.allowUnfree = true;
      };
      # Custom Overlay
      overlay = final: prev: {
        # Browser and Tools
        inherit (nixpkgs-responsively-mr.legacyPackages.${prev.system})
          responsively-desktop
          ;
        inherit (nixpkgs-zen-mr.legacyPackages.${prev.system})
          zen-browser-unwrapped
          ;
        # System Utilities
        rio = rio-term.packages.${prev.system}.rio.overrideAttrs (old: {
          doCheck = false;
          buildFeatures = [ "wayland" ];
        });
      };
    in
    {
      packages.${system} = import ./pkgs {
        inherit
          nixpkgs
          pkgs-stable
          pkgs-unstable
          pkgs-master
          ;
        pkgs = nixpkgs.legacyPackages.${system};
      };

      nixosConfigurations = {

        ntsv = nixpkgs.lib.nixosSystem {
          inherit system;

          # Special Arguments
          specialArgs = {
            inherit
              inputs
              pkgs-stable
              pkgs-unstable
              pkgs-master
              self
              system
              ;
          };

          modules = [
            # Core Modules
            {
              imports = [
                "${nixpkgs-unstable}/nixos/modules/services/scheduling/scx.nix"
              ];
            }
            lix-module.nixosModules.default
            stylix.nixosModules.stylix
            niri.nixosModules.niri
            ./overlays
            # Overlays
            {
              nixpkgs.overlays = [
                inputs.nix-vscode-extensions.overlays.default
                overlay

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
            chaotic.nixosModules.default
            lanzaboote.nixosModules.lanzaboote
            ./secureboot.nix
          ];
        };
      };

      # Formatter Configuration
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
    };
}
