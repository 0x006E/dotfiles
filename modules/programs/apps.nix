{ delib, ... }:
delib.module {
  name = "programs.apps";

  home.always =
    { myconfig, ... }:
    {
      pkgs,
      pkgs-stable,
      config,
      lib,
      ...
    }:
    {
      home.packages = with pkgs; [
        librum
        winboat
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
