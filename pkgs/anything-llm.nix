{ appimageTools, fetchurl }:
let
  pname = "anything-llm-desktop";
  version = "1.7.0";

  src = fetchurl {
    url = "https://s3.us-west-1.amazonaws.com/public.useanything.com/legacy/${version}/AnythingLLMDesktop.AppImage";
    hash = "sha256-9+aDgNqAmuker8gEYZgiY2Yi53IIWdPa2521dE57Kcw=";
  };
in
appimageTools.wrapType2 {
  inherit pname version src;
}
