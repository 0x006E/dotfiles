{ delib, ... }:
delib.module {
  name = "hardware.kanata";

  nixos.always =
    { ... }:
    { ... }:
    {
      services.kanata = {
        enable = false; # Disabled because of errors in original configuration
        keyboards.default.configFile = ./homerow-mods.kdb;
      };
    };
}
