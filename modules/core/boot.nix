{ delib, inputs, ... }:
delib.module {
  name = "core.boot";

  nixos.always = { myconfig, ... }: { pkgs, config, lib, ... }: {
    imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];
    boot = {
      loader = {
        systemd-boot = {
          enable = true;
          configurationLimit = 3;
        };
        efi.canTouchEfiVariables = true;
        timeout = 0;
      };
      blacklistedKernelModules = [
        "iTCO_wdt"
        "iTCO_vendor_support"
      ];
      kernelModules = [
        "acer-wmi-battery"
        "coretemp"
      ];
      extraModprobeConfig = ''
        options iwlmvm power_scheme=2
        options iwlwifi 11n_disable=8
        options acer_wmi_battery enable_health_mode=1
      '';
      resumeDevice = "/dev/dm-0";
      kernelParams = [
        "nowatchdog"
        "resume_offset=1058048"
        "nvidia_drm.fbdev=1"
        "nvidia.NVreg_PreserveVideoMemoryAllocations=0"
      ];
      kernel.sysctl = {
        "vm.admin_reserve_kbytes" = 1048576;
        "vm.oom_kill_allocating_task" = 1;
        "kernel.sysrq" = 438;
        "vm.dirty_writeback_centisecs" = 6000;
        "vm.dirty_background_ratio" = 5;
        "vm.dirty_ratio" = 10;
      };
    };

    swapDevices = [
      {
        device = "/swap/swapfile";
        size = 16 * 1024;
      }
    ];

    zramSwap = {
      enable = true;
      memoryPercent = 100;
      priority = 10;
    };
  };
}
