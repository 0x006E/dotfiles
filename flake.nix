{
  description = "Nithin's NixOS Configuration with Denix";

  inputs = {
    # Core Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable-small";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";
    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    };

    # Denix
    denix = {
      url = "github:yunfachi/denix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Desktop and UI
    stylix = {
      url = "github:danth/stylix";
    };
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Development Tools
    nixvim = {
      url = "github:nix-community/nixvim";

    };
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # System Management
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        rust-overlay.follows = "rust-overlay";
      };
    };
    erosanix = {
      url = "github:emmanuelrosa/erosanix"; # Utilities
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak = {
      url = "github:gmodena/nix-flatpak/?ref=latest";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    battery-notifier = {
      url = "github:luisnquin/battery-notifier";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-github-actions = {
      url = "github:nix-community/nix-github-actions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia/cachix";
    };
    antigravity = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      denix,
      nixpkgs,
      nixpkgs-stable,
      nixpkgs-unstable,
      nix-github-actions,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      pkgs-stable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };

      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      mkConfigurations =
        moduleSystem:
        denix.lib.configurations {
          inherit moduleSystem;
          homeManagerUser = "nithin";

          paths = [
            ./hosts
            ./modules
            ./rices
          ];

          extensions = with denix.lib.extensions; [
            args
            (base.withConfig {
              args.enable = true;
            })
          ];

          specialArgs = {
            inherit
              inputs
              pkgs-stable
              pkgs-unstable
              self
              system
              ;
          };
        };
    in
    {
      packages.${system} =
        (import ./pkgs {
          inherit
            nixpkgs
            pkgs-stable
            pkgs-unstable
            inputs
            system
            ;

          pkgs = nixpkgs.legacyPackages.${system};
        })
        // {
          papers = self.nixosConfigurations.ntsv.pkgs.papers;
          inkscape = self.nixosConfigurations.ntsv.pkgs.inkscape;
          catppuccin-cursors-mochaLight = self.nixosConfigurations.ntsv.pkgs.catppuccin-cursors.mochaLight;
          catppuccin-cursors-latteDark = self.nixosConfigurations.ntsv.pkgs.catppuccin-cursors.latteDark;
        };

      githubActions = nix-github-actions.lib.mkGithubMatrix { checks = self.packages; };

      nixosConfigurations = mkConfigurations "nixos";

      # Formatter Configuration
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;

      devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
        packages = with nixpkgs.legacyPackages.${system}; [
          nil
          nixd
          nixfmt
          statix
          deadnix
          pre-commit
        ];
      };
    };
}
