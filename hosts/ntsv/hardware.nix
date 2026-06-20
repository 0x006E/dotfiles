{ delib, ... }:
delib.host {
  name = "ntsv";

  system = "x86_64-linux";

  home.home.stateVersion = "24.05";

  nixos = {
    system.stateVersion = "24.05";
    imports = [
      ../../custom-hardware/hardware-configuration.nix
      ({ config, ... }: {
        boot.extraModulePackages = [
          (config.boot.kernelPackages.callPackage ../../custom-hardware/uvcvideo-kernel-module.nix { })
          (config.boot.kernelPackages.callPackage ../../custom-hardware/acer-wmi-battery.nix { })
        ];
      })
    ];
  };
}
