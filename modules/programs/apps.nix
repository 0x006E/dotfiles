{ delib, ... }:
delib.module {
  name = "programs.apps";

  home.always =
    { myconfig, ... }:
    {
      pkgs,
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
        stirling-pdf
        heroic
        bottles
        winetricks
        wineWow64Packages.waylandFull
      ];
    };
}
