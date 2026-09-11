{ delib, ... }:
delib.module {
  name = "programs.media";
  options = delib.singleEnableOption true;

  nixos.ifEnabled = { ... }: {
    # Flatpak itself stays for manually installed apps (e.g. NAPS2).
    # Uses the stock nixpkgs service module — no declarative apps.
    services.flatpak.enable = true;
  };
}
