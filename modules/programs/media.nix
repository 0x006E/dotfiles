{ delib, inputs, ... }:
delib.module {
  name = "programs.media";
  options = delib.singleEnableOption true;

  nixos.always = {
    imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];
  };

  nixos.ifEnabled = { myconfig, cfg, ... }: {
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
}
