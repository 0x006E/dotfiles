{
  pkgs,
  lib,
  ...
}:

{
  specialisation = {
    mini.configuration = {
      services.xserver.desktopManager.plasma5.enable = true;
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
        okular
      ];
    };
  };
}
