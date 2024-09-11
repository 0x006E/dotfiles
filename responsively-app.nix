{
  pkgs,
  lib,
  ...
}: let
  pname = "responsivelyapp";
  version = "1.12.0";
  name = "${pname}-${version}";

  src = pkgs.fetchurl {
    url = "https://github.com/responsively-org/responsively-app-releases/releases/download/v${version}/ResponsivelyApp-${version}.AppImage";
    sha256 = "sha256-qW6vEOAUZVHdNmn8QWmBGksIjYXez0IGei/AYrxn1VQ=";
  };

  appimageContents = pkgs.appimageTools.extractType2 {inherit name src;};
in
  pkgs.appimageTools.wrapType2 rec {
    inherit name src;

    extraInstallCommands = ''
      mv $out/bin/${name} $out/bin/${pname}
      install -m 444 -D ${appimageContents}/${pname}.desktop $out/share/applications/${pname}.desktop

      install -m 444 -D ${appimageContents}/${pname}.png $out/share/icons/hicolor/512x512/apps/${pname}.png

      substituteInPlace $out/share/applications/${pname}.desktop \
      	--replace 'Exec=AppRun --no-sandbox %U' 'Exec=${pname} %U'
    '';

    meta = with lib; {
      description = " A must-have devtool for web developers for quicker responsive web development. 🚀 ";
      homepage = "https://responsively.app/";
      license = licenses.gpl3;
      maintainers = [];
      platforms = ["x86_64-linux"];
    };
  }
