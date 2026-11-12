{
  appimageTools,
  fetchurl,
  lib,
}:
let
  version = "1.3.0";
  src = fetchurl {
    url = "https://github.com/SimoHypers/limusic/releases/download/v${version}/limusic_${version}_amd64.AppImage";
    hash = "sha256-skhW7OeTMN06Y/WvI5Tm+Dja50rtxh42d0Q96Qwrc4c=";
  };
  appimageContents = appimageTools.extract {
    pname = "limusic";
    inherit version src;
  };
in
appimageTools.wrapAppImage {
  pname = "limusic";
  inherit version;
  # The AppImage bundles its own libwebkit/libmpv/gstreamer stack and its
  # AppRun hooks repoint GIO/GStreamer/GTK paths at the bundled copies, so
  # the FHS env only needs the base set plus these two (same set as the
  # community limusic-nix flake).
  extraPkgs =
    pkgs: with pkgs; [
      webkitgtk_4_1
      libappindicator-gtk3
    ];
  src = appimageContents;
  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/usr/share/applications/limusic.desktop \
      $out/share/applications/limusic.desktop
    substituteInPlace $out/share/applications/limusic.desktop \
      --replace-fail 'Exec=limusic-app' 'Exec=limusic' \
      --replace-fail 'Name=limusic' 'Name=LiMusic'
    mkdir -p $out/share/icons
    cp -R ${appimageContents}/usr/share/icons/hicolor $out/share/icons/
  '';
  # nix-update (the CI package updater) reads pkg.src.urls/outputHash, but
  # wrapAppImage replaces the src attr with the extracted tree. Republish the
  # fetchurl so `nix-update --flake limusic` keeps working.
  passthru.src = src;
  meta = {
    description = "Feature-rich native desktop YouTube Music client";
    homepage = "https://limusic.app";
    changelog = "https://github.com/SimoHypers/limusic/releases/tag/v${version}";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "limusic";
  };
}
