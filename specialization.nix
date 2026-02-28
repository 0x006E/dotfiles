{
  pkgs,
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
      programs.niri.enable = false;
      environment.systemPackages = with pkgs; [
        okular
      ];
    };

    paul = {
      inheritParentConfig = false;
      configuration = {
        system.nixos.tags = [ "paul" ];
        services.xserver.desktopManager.gnome.enable = true;
        users.users.paul = {
          isNormalUser = true;
          uid = 1002;
          extraGroups = [
            "networkmanager"
            "video"
          ];
        };
        services.xserver.displayManager.autoLogin = {
          enable = true;
          user = "paul";
        };
        environment.systemPackages = with pkgs; [
          dune-release
        ];
      };
    };
  };
}
