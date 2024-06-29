{
  fetchzip,
  appimageTools,
  makeDesktopItem,
  ...
}: let
  extracted-zip = fetchzip {
    src = "https://github.com/responsively-org/responsively-app-releases/releases/download/v1.12.0/ResponsivelyApp-1.12.0.AppImage";
    sha256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";
  }; # 1
  appimage-file = "${extracted-zip}/PokeWilds-x64"; # 2
in
  appimageTools.wrapType2 {
    name = "Responsively App";
    version = "1.12.0";
    src = appimage-file; # 3

    # desktopItems = [
    #   (makeDesktopItem {
    #     name = "drawio";
    #     exec = "drawio %U";
    #     icon = "drawio";
    #     desktopName = "drawio";
    #     comment = "draw.io desktop";
    #     mimeTypes = ["application/vnd.jgraph.mxfile" "application/vnd.visio"];
    #     categories = ["Graphics"];
    #     startupWMClass = "drawio";
    #   })
    # ];
  } {}
