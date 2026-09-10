{ delib, inputs, ... }:
delib.module {
  name = "core.boot";

  nixos.always =
    { ... }:
    {
      pkgs,
      ...
    }:
    {
      imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];
      # Track the newest kernel for the latest iwlwifi + firmware API
      # (attempt at fixing the AX211 CNVi crashes; watch the nvidia
      # module build — stable lags behind brand-new kernels).
      boot.kernelPackages = pkgs.linuxPackages_latest;
      # Acer Aspire A515-57G (1025:1616, ALC256): BIOS leaves pin 0x19
      # (Headset Mic) as N/A + NO_PRESENCE, so the kernel only matches
      # the generic Acer fallback quirk, which enables per-pin
      # unsolicited jack detection on an unwired presence input. The
      # resulting plug/unplug storm (~300 events/s) wedges WirePlumber
      # at 100% CPU and kills all audio incl. Bluetooth. Force the
      # Acer-specific quirk (headset mic via headset-mode detection,
      # like the Swift SF314-54) instead.
      boot.kernelPatches = [
        {
          name = "acer-a515-57g-alc256-headset-mic";
          patch = ../hardware/acer-a515-57g-alc256-quirk.patch;
        }
      ];
      boot = {
        loader = {
          # Secure Boot is handled by lanzaboote (core.secureboot), which
          # disables systemd-boot; keep configurationLimit since lanzaboote
          # still reads it for its installer.
          systemd-boot.configurationLimit = 3;
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
          # AX211 CNVi (00:14.3) crashes with SYSASSERT then needs a cold boot
          # (PCH keeps the wedged state across reboot + module reload).
          # power_scheme=1 keeps the radio awake; balanced/low-power lets it
          # wedge, usually right after assoc.
          options iwlmvm power_scheme=1
          options iwlwifi 11n_disable=8
          options acer_wmi_battery enable_health_mode=1
        '';
        resumeDevice = "/dev/dm-0";
        kernelParams = [
          "nowatchdog"
          "resume_offset=1058048"
          "pcie_aspm=off" # AX200/iwlwifi stability
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
