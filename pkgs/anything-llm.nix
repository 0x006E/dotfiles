{ appimageTools, fetchurl }:
let
  pname = "anything-llm-desktop";
  version = "1.7.0";

  src = fetchurl {
    url = "https://s3.us-west-1.amazonaws.com/public.useanything.com/legacy/${version}/AnythingLLMDesktop.AppImage";
    hash = "";
  };
in
appimageTools.wrapType2 {
  inherit pname version src;
}
