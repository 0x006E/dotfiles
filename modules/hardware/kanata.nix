{ delib, ... }:
delib.module {
  name = "hardware.kanata";
  options = delib.singleEnableOption true;

  nixos.ifEnabled = { ... }: {
    services.kanata = {
      # Re-enabled: the old failure left no surviving logs, but the config
      # validates clean on kanata 1.12 (--check), and the module runs the
      # service as DynamicUser with input/uinput groups, so device access
      # is handled. Scoped to the internal keyboard in homerow-mods.kdb.
      enable = true;
      keyboards.default.configFile = ./homerow-mods.kdb;
    };
  };
}
