{ delib, inputs, ... }:
delib.module {
  name = "programs.media";
  options = delib.singleEnableOption true;

  nixos.always = {
    imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];
  };

  nixos.ifEnabled = { ... }: {
    # Flatpak itself stays: manually installed apps (e.g. NAPS2) live
    # outside nix-flatpak. No declarative apps or remotes right now.
    services.flatpak.enable = true;
  };
}
