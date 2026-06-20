{ delib, ... }:
delib.host {
  name = "ntsv";

  system = "x86_64-linux";

  home.home.stateVersion = "24.05";

  nixos = {
    system.stateVersion = "24.05";
    imports = [
      ./hardware-configuration.nix
      (
        { config, ... }:
        {
          boot.extraModulePackages = [
            (config.boot.kernelPackages.callPackage ../../pkgs/uvcvideo-kernel-module { })
            (config.boot.kernelPackages.callPackage ../../pkgs/acer-wmi-battery { })
          ];
        }
      )
    ];
  };
}
