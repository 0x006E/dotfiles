{
  description = "Nithin's NixOS Configuration";

  inputs = {
    # Core Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-unstable.url = "nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";

    # Custom Nixpkgs Forks
    nixpkgs-matthewpi.url = "github:matthewpi/nixpkgs/zen-browser";
    nixpkgs-k900.url = "github:K900/nixpkgs/kernels-20241118";
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
    nixos-cosmic.url = "github:lilyinstarlight/nixos-cosmic";
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
      nixpkgs-matthewpi,
      nixpkgs-k900,
      home-manager,
      chaotic,
      lanzaboote,
      niri,
      lix-module,
      stylix,
      nixos-cosmic,
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
      pkgs-k900 = import nixpkgs-k900 {
        inherit system;
        config.allowUnfree = true;
      };

      # Custom Overlay
      overlay = final: prev: {
        # Browser and Tools
        inherit (nixpkgs-matthewpi.legacyPackages.${prev.system})
          zen-browser-unwrapped
          ;
        # System Utilities
        inherit (pkgs-k900)
          linuxPackages_latest
          ;
        inherit (inputs.conky.packages.${prev.system})
          conky
          ;
        bpftune = prev.bpftune.overrideAttrs (old: {
          version = "0-unstable-2024-10-25";

          src = old.src.override {
            rev = "6a50f5ff619caeea6f04d889e3a60de6c12feb76";
            hash = "sha256-yol6VFelqQiPKLg1UUeP+r/+XO4fjYeDbIeI29gZ7j4=";
          };

          postPatch = ''
            # otherwise shrink rpath would drop $out/lib from rpath
            substituteInPlace src/Makefile \
              --replace-fail /sbin    /bin \
              --replace-fail ldconfig true
            substituteInPlace src/bpftune.service \
              --replace-fail /usr/sbin/bpftune "$out/bin/bpftune"
            substituteInPlace src/libbpftune.c \
              --replace-fail /lib/modules /run/booted-system/kernel-modules/lib/modules
          '';
          makeFlags = old.makeFlags ++ [
            "libdir=lib"
          ];

        });

        rio = rio-term.packages.${prev.system}.rio.overrideAttrs (old: {
          doCheck = false;
          buildFeatures = [ "wayland" ];
        });
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
            {
              nix.settings = {
                substituters = [ "https://cosmic.cachix.org/" ];
                trusted-public-keys = [ "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE=" ];
              };
            }
            nixos-cosmic.nixosModules.default

            ./secureboot.nix
          ];
        };
      };

      # Formatter Configuration
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
    };
}
