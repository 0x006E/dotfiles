{ delib, ... }:
delib.module {
  name = "services.desktop-services";
  options = delib.singleEnableOption true;

  nixos.ifEnabled = { ... }: {
    services = {
      gnome.gcr-ssh-agent.enable = false;
      libinput.enable = true;
    };

    programs.dconf.enable = true;
    services.displayManager.regreet.enable = false;
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;
  };
}
