{
  delib,
  pkgs,
  pkgs-stable,
  ...
}:
delib.module {
  name = "programs.apps";
  options = delib.singleEnableOption true;

  home.ifEnabled = { ... }: {
    home.packages = with pkgs; [
      librum
      # TODO: re-enable once winboat drops electron_40 (EOL/insecure in nixpkgs, nixpkgs#537847)
      # winboat
      filen-cli
      filen-desktop
      libreoffice
      gimp
      pre-commit
      foot
      overskride
      mpv
      pkgs-stable.bottles
      winetricks
    ];
  };
}
