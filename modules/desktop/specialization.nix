{ delib, ... }:
delib.module {
  name = "desktop.specialization";
  nixos.always =
    { myconfig, ... }:
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
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
