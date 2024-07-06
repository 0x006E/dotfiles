{
  pkgs,
  lib,
  ...
}: let
  pname = "zoho-mail-desktop-lite";
  version = "1.6.3";
  name = "${pname}-${version}";

  src = pkgs.fetchurl {
    url = "https://downloads.zohocdn.com/zmail-desktop/linux/zoho-mail-desktop-lite-x64-v${version}.AppImage";
    sha256 = "sha256-qW6vEOAUZVHdNmn8QWmBGksIjYXez0IGei/AYrxn1VQ=";
  };

  appimageContents = pkgs.appimageTools.extractType2 {inherit name src;};
in
  pkgs.appimageTools.wrapType2 rec {
    inherit name src;

    extraInstallCommands = ''
      mv $out/bin/${name} $out/bin/${pname}
      ls -l
      install -m 444 -D ${appimageContents}/${pname}.desktop $out/share/applications/${pname}.desktop

      install -m 444 -D ${appimageContents}/${pname}.png $out/share/icons/hicolor/512x512/apps/${pname}.png

      substituteInPlace $out/share/applications/${pname}.desktop \
      	--replace 'Exec=AppRun --no-sandbox %U' 'Exec=${pname} %U'
    '';

    meta = with lib; {
      description = "Zoho webmail desktop client.";
      homepage = "https://www.zoho.com/mail/desktop/";
      license = licenses.unfree;
      maintainers = [];
      platforms = ["x86_64-linux"];
    };
  }
