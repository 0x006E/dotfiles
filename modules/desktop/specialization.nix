{
  delib,
  pkgs,
  lib,
  ...
}:
delib.module {
  name = "desktop.specialization";
  options = delib.singleEnableOption true;

  nixos.ifEnabled = { ... }: {
    specialisation = {
      mini.configuration = {
        services.desktopManager.gnome.enable = lib.mkForce true;
        services.desktopManager.plasma6.enable = true;
        users.users.mini = {
          isNormalUser = true;
          uid = 1002;
          extraGroups = [
            "networkmanager"
            "video"
            "input"
          ];
        };
        programs.niri.enable = lib.mkForce false;
        environment.systemPackages = with pkgs; [
          kdePackages.okular
        ];
      };
    };
  };
}
