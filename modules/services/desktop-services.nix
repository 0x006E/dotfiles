{ delib, ... }:
delib.module {
  name = "services.desktop-services";

  nixos.always =
    { ... }:
    {
      ...
    }:
    {
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
