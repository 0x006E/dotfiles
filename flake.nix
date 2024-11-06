{
  description = "Nithin's NixOS Configuration";

  inputs = {
    # Core Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-unstable.url = "nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.05";

    # Custom Nixpkgs Forks
    nixpkgs-kuglimon.url = "github:kuglimon/nixpkgs/vtsls";
    nixpkgs-matthewpi.url = "github:matthewpi/nixpkgs/zen-browser";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Desktop and UI
    stylix.url = "github:danth/stylix";
    niri.url = "github:sodiboo/niri-flake";
    conky.url = "github:brndnmtthws/conky";

    # Development Tools
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
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
      nixpkgs,
      nixpkgs-stable,
      nixpkgs-unstable,
      nixpkgs-kuglimon,
      nixpkgs-matthewpi,
      home-manager,
      chaotic,
      lanzaboote,
      niri,
      lix-module,
      stylix,
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

      # Custom Overlay
      overlay = final: prev: {
        # Browser and Tools
        inherit (nixpkgs-matthewpi.legacyPackages.${prev.system})
          zen-browser
          ;

        # Development Tools
        inherit (nixpkgs-kuglimon.legacyPackages.${prev.system})
          vtsls
          ;

        # System Utilities
        inherit (inputs.conky.packages.${prev.system})
          conky
          ;
      };
    in
    {
      nixosConfigurations = {
        ntsv = nixpkgs.lib.nixosSystem {
          inherit system;

          # Special Arguments
          specialArgs = {
            inherit inputs pkgs-stable pkgs-unstable;
          };

          modules = [
            # Core Modules
            lix-module.nixosModules.default
            stylix.nixosModules.stylix
            niri.nixosModules.niri

            # Overlays
            {
              nixpkgs.overlays = [
                (self: super: {
                  mpv = super.mpv.override {
                    scripts = [ self.mpvScripts.mpris ];
                  };
                })
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
