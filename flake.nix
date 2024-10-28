{
  description = "System Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-unstable.url = "nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-kuglimon.url = "github:kuglimon/nixpkgs/vtsls";
    nixpkgs-matthewpi.url = "github:matthewpi/nixpkgs/zen-browser";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nil.url = "github:oxalica/nil";
    niri.url = "github:sodiboo/niri-flake";
    ags.url = "github:Aylur/ags";
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    walker.url = "github:abenz1267/walker";
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lix = {
      url = "https://git.lix.systems/lix-project/lix/archive/main.tar.gz";
      flake = false;
    };
    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/main.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.lix.follows = "lix";
    };
    blink-cmp.url = "github:Saghen/blink.cmp";
    wezterm-flake.url = "github:wez/wezterm/main?dir=nix";
    wezterm-flake.inputs.nixpkgs.follows = "nixpkgs";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
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
      overlay = final: prev: {
        inherit (nixpkgs-matthewpi.legacyPackages.${prev.system})
          zen-browser
          ;
        # Inherit the changes into the overlay
        inherit (nixpkgs-kuglimon.legacyPackages.${prev.system})
          vtsls
          ;
      };
    in
    {
      nixosConfigurations = {
        ntsv = nixpkgs.lib.nixosSystem {

          system = "x86_64-linux";
          specialArgs = {
            inherit inputs;
            inherit pkgs-stable;
            inherit pkgs-unstable;
          };
          modules = [
            lix-module.nixosModules.default
            niri.nixosModules.niri
            {
              nixpkgs.overlays = [
                (self: super: { mpv = super.mpv.override { scripts = [ self.mpvScripts.mpris ]; }; })
                inputs.nix-vscode-extensions.overlays.default # Also have a look at https://github.com/nix-community/nix-vscode-extensions/issues/29
                overlay
              ];
            }
            ./configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;

              home-manager.extraSpecialArgs = {
                inherit inputs;
                inherit pkgs-unstable;
                inherit pkgs-stable;
              };
              home-manager.users.nithin = import ./home.nix;

              home-manager.backupFileExtension = "bak"; # Optionally, use home-manager.extraSpecialArgs to pass
            }
            chaotic.nixosModules.default
            lanzaboote.nixosModules.lanzaboote
            ./secureboot.nix
          ];
        };
      };
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
    };
}
