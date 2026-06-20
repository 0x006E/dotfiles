{ delib, inputs, ... }:
delib.module {
  name = "programs.media";

  nixos.always = { myconfig, ... }: { pkgs, config, lib, ... }: {
    imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];
    services.flatpak = {
      enable = true;
      remotes = [
        {
          name = "flathub-beta";
          location = "https://flathub.org/beta-repo/flathub-beta.flatpakrepo";
        }
      ];
      packages = [
        {
          appId = "com.stremio.Stremio";
          origin = "flathub-beta";
        }
      ];
    };
  };

  home.always = { myconfig, ... }: { pkgs, config, lib, ... }: {
    home.packages = with pkgs; [
      librum
      winboat
      filen-cli
      filen-desktop
      libreoffice
      gimp
      foot
      overskride
      mpv
      stirling-pdf
      deluge
      shotwell
      (lutris.override {
        extraLibraries = pkgs: [
          mangohud
          wineWowPackages.waylandFull
          bash
          winetricks
        ];
      })
    ];
  };
}
