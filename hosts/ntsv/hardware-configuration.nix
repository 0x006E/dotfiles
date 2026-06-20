{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Boot Configuration
  boot = {
    # Kernel Modules
    initrd = {
      availableKernelModules = [
        "xhci_pci" # USB 3.0 controller
        "thunderbolt" # Thunderbolt controller
        "vmd" # Intel Volume Management Device
        "ahci" # SATA controller
        "nvme" # NVMe drives
        "usb_storage" # USB storage devices
        "sd_mod" # SD card reader
      ];
      kernelModules = [ ];

      # LUKS Configuration
      luks.devices."crypted" = {
        device = "/dev/disk/by-uuid/a868c4bd-b34b-4593-9307-a0cb13cd41a8";
      };
    };

    kernelModules = [ "kvm-intel" ]; # Intel KVM support
    extraModulePackages = [ ];
  };

  # Filesystem Configuration
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/1703ff9d-bde4-44b2-9f99-5cd211642af1";
      fsType = "btrfs";
      options = [ "subvol=@" ];
    };

    "/home" = {
      device = "/dev/disk/by-uuid/1703ff9d-bde4-44b2-9f99-5cd211642af1";
      fsType = "btrfs";
      options = [ "subvol=@home" ];
    };

    "/swap" = {
      device = "/dev/disk/by-uuid/1703ff9d-bde4-44b2-9f99-5cd211642af1";
      fsType = "btrfs";
      options = [ "subvol=@swap" ];
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/AB72-D331";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
  };

  # Network Configuration
  networking = {
    useDHCP = lib.mkDefault true;
  };

  # System Configuration
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Hardware Configuration
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
