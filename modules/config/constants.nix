{ delib, inputs, ... }:
delib.module {
  name = "constants";

  options.constants = with delib; {
    username = readOnly (strOption "nithin");
    userfullname = readOnly (strOption "Nithin S Varrier");
    useremail = readOnly (strOption "me@ntsv.dev");
  };
}
