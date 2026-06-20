{ delib, inputs, ... }:
delib.module {
  name = "desktop.stylix";

  nixos.always =
    { myconfig, ... }:
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      imports = [ inputs.stylix.nixosModules.stylix ];
      stylix = {
        enable = true;
        fonts = {
          monospace = {
            package = pkgs.nerd-fonts.commit-mono;
            name = "CommitMono Nerd Font";
          };
        };
        targets.qt.enable = false;
      };

      boot = {
        kernelParams = [
          "quiet"
          "splash"
          "bgrt_disable"
          "rd.systemd.show_status=false"
          "rd.udev.log_level=3"
          "udev.log_priority=3"
          "boot.shell_on_fail"
        ];
        initrd.verbose = false;
        consoleLogLevel = 0;
        plymouth.enable = true;
      };
      environment.systemPackages = [ pkgs.plymouth ];
    };

  home.always =
    { myconfig, ... }:
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      stylix.targets.zen-browser.profileNames = [ "nithin" ];
    };
}
