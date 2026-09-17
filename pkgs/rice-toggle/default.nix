{
  lib,
  stdenv,
  makeWrapper,
  sunwait,
  libnotify,
  glib,
}:
stdenv.mkDerivation {
  pname = "rice-toggle";
  version = "0.1.0";

  src = ./toggle.sh;
  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/rice-toggle"
    # sunwait/notify-send/gsettings resolved from the closure; noctalia
    # comes from the user session PATH (HM installs it).
    wrapProgram "$out/bin/rice-toggle" \
      --prefix PATH : "${
        lib.makeBinPath [
          sunwait
          libnotify
          glib
        ]
      }"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Apply day/night desktop polarity (Noctalia theme, wallpaper, greeter) without rebuilding";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "rice-toggle";
  };
}
