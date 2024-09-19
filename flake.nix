{
  description = "System Configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.05";
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
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # nixos-cosmic = {
    #   url = "github:lilyinstarlight/nixos-cosmic";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/main.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser.url = "github:MarceColl/zen-browser-flake";
    wezterm-flake.url = "github:wez/wezterm/main?dir=nix";
    wezterm-flake.inputs.nixpkgs.follows = "nixpkgs";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
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
    nix-vscode-extensions,
    wezterm-flake,
    nix-index-database,
    lix-module,
    # nixos-cosmic,
    zen-browser,
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
          lix-module.nixosModules.default
          niri.nixosModules.niri
          {
            environment.systemPackages = [alejandra.defaultPackage.${system}];
            nixpkgs.overlays = [
              (self: super: {mpv = super.mpv.override {scripts = [self.mpvScripts.mpris];};})
              inputs.nix-vscode-extensions.overlays.default # Also have a look at https://github.com/nix-community/nix-vscode-extensions/issues/29
            ];
          }
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.extraSpecialArgs = {
              inherit inputs;
            };
            home-manager.users.nithin = import ./home.nix;

            home-manager.backupFileExtension = "bak"; # Optionally, use home-manager.extraSpecialArgs to pass
            # arguments to home.nix
          }
          # {
          #   nix.settings = {
          #     substituters = [ "https://cosmic.cachix.org/" ];
          #     trusted-public-keys = [ "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE=" ];
          #   };
          # }
          # nixos-cosmic.nixosModules.default
          chaotic.nixosModules.default
          lanzaboote.nixosModules.lanzaboote
          ./secureboot.nix
        ];
      };
    };
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;
  };
}
