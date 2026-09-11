{ delib, ... }:
delib.module {
  name = "hardware.kanata";
  options = delib.singleEnableOption true;

  nixos.ifEnabled = { myconfig, ... }: {
    services.kanata = {
      # Re-enabled: the old failure left no surviving logs, but the config
      # validates clean on kanata 1.12 (--check), and the module runs the
      # service as DynamicUser with input/uinput groups, so device access
      # is handled.
      enable = true;
      keyboards.default.configFile = ./homerow-mods.kdb;
    };

    # Passwordless kanata toggle for the Mod+Shift+K bind: narrow polkit
    # rule scoped to this one unit and this user only.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (
          action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "kanata-default.service" &&
          subject.user == "${myconfig.constants.username}"
        ) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
