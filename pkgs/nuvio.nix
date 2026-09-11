{
  lib,
  appimageTools,
  fetchurl,
}:
appimageTools.wrapType2 rec {
  pname = "nuvio";
  version = "0.1.23-alpha";

  src = fetchurl {
    url = "https://github.com/NuvioMedia/NuvioDesktop/releases/download/${version}/Nuvio-Linux-x86_64-${version}.AppImage";
    hash = "sha256-1Oe5TxiGmiozbWgOr/0BJL9BDCpYY9/pP4MnAj5YgDE=";
  };

  extraInstallCommands =
    let
      contents = appimageTools.extract { inherit pname version src; };
    in
    ''
      install -Dm444 ${contents}/Nuvio.desktop $out/share/applications/Nuvio.desktop
      install -Dm444 ${contents}/Nuvio.png $out/share/icons/hicolor/256x256/apps/Nuvio.png
      substituteInPlace $out/share/applications/Nuvio.desktop \
        --replace "Exec=AppRun" "Exec=nuvio"
    '';

  meta = with lib; {
    description = "Desktop media client for browsing and playing media (alpha)";
    homepage = "https://nuvio.tv";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
    mainProgram = "nuvio";
  };
}
