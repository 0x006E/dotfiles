{ delib, ... }:
delib.module {
  name = "services.desktop-services";

  nixos.always = { myconfig, ... }: { pkgs, config, lib, ... }: {
    services = {
      gnome.gcr-ssh-agent.enable = false;
      libinput.enable = true;
    };

    programs.dconf.enable = true;
    programs.regreet.enable = false;
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;
  };
}
