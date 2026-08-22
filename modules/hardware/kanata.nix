{ delib, ... }:
delib.module {
  name = "hardware.kanata";
  options = delib.singleEnableOption true;

  nixos.ifEnabled = { ... }: {
    services.kanata = {
      enable = false; # Disabled because of errors in original configuration
      keyboards.default.configFile = ./homerow-mods.kdb;
    };
  };
}
