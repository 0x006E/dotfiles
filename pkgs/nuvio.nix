{ lib, appimageTools, fetchurl, symlinkJoin, makeWrapper, mpv }:
let
  version = "0.1.23-alpha";
  src = fetchurl {
    url = "https://github.com/NuvioMedia/NuvioDesktop/releases/download/${version}/Nuvio-Linux-x86_64-${version}.AppImage";
    hash = "sha256-1Oe5TxiGmiozbWgOr/0BJL9BDCpYY9/pP4MnAj5YgDE=";
  };
  unwrapped = appimageTools.wrapType2 {
    pname = "nuvio";
    inherit version src;
    extraInstallCommands =
      let
        contents = appimageTools.extract { pname = "nuvio"; inherit version src; };
      in
      ''
        install -Dm444 ${contents}/Nuvio.desktop $out/share/applications/Nuvio.desktop
        install -Dm444 ${contents}/Nuvio.png $out/share/icons/hicolor/256x256/apps/Nuvio.png
        substituteInPlace $out/share/applications/Nuvio.desktop \
          --replace "Exec=AppRun" "Exec=nuvio"
      '';
  };
in
symlinkJoin {
  name = "nuvio-${version}";
  paths = [ unwrapped ];
  nativeBuildInputs = [ makeWrapper ];
  # The app extracts libplayer_bridge.so to ~/.cache at runtime and dlopens
  # it; that bridge links against the HOST libmpv (not bundled), so expose
  # it or every playback ends in UnsatisfiedLinkError: libmpv.so.2.
  postBuild = ''
    wrapProgram $out/bin/nuvio \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ mpv ]}"
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
