{ delib, inputs, ... }:
delib.module {
  name = "hardware.nvidia";

  nixos.always =
    { myconfig, ... }:
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.nvidia = {
        modesetting.enable = false;
        powerManagement.enable = true;
        powerManagement.finegrained = true;
        open = false;
        nvidiaPersistenced = false;
        nvidiaSettings = true;
        package = config.boot.kernelPackages.nvidiaPackages.stable;
        prime = {
          offload.enable = true;
          offload.enableOffloadCmd = true;
          intelBusId = "PCI:0:2:0";
          nvidiaBusId = "PCI:2:0:0";
        };
      };
      boot.kernelParams = [ "nvidia.NVreg_EnableS0ixPowerManagement=1" ];
    };
}
