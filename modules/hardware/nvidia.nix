{
  delib,
  config,
  pkgs,
  ...
}:
delib.module {
  name = "hardware.nvidia";
  options = delib.singleEnableOption true;

  nixos.ifEnabled = { ... }: {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-vaapi-driver
        libvdpau-va-gl
      ];
    };
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia = {
      modesetting.enable = true;
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
    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "iHD";
    };
  };
}
