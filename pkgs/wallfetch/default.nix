{
  lib,
  stdenv,
  makeWrapper,
  curl,
  jq,
  imagemagick,
  coreutils,
  findutils,
}:
stdenv.mkDerivation {
  pname = "wallfetch";
  version = "0.1.0";

  src = ./fetch.sh;
  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/wallfetch"
    wrapProgram "$out/bin/wallfetch" \
      --prefix PATH : "${
        lib.makeBinPath [
          curl
          jq
          imagemagick
          coreutils
          findutils
        ]
      }"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Fetch top wallhaven wallpapers, classify dark/light, crop to output size";
    homepage = "https://wallhaven.cc";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "wallfetch";
  };
}
