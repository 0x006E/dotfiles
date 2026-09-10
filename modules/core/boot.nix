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
      # NOTE: the diff below is flush-left on purpose — patch files are
      # whitespace-sensitive, so the string content must not be indented.
      boot.kernelPatches = [
        {
          name = "acer-a515-57g-alc256-headset-mic";
          # Inline (writeText) instead of a separate file: flake lazy-trees
          # only see git-committed files, so a new loose .patch would break
          # evaluation until committed.
          patch = pkgs.writeText "acer-a515-57g-alc256-quirk.patch" ''
            diff --git a/sound/hda/codecs/realtek/alc269.c b/sound/hda/codecs/realtek/alc269.c
            --- a/sound/hda/codecs/realtek/alc269.c
            +++ b/sound/hda/codecs/realtek/alc269.c
            @@ -6950,7 +6950,8 @@ static const struct hda_quirk alc269_fixup_tbl[] = {
             	SND_PCI_QUIRK(0x1025, 0x159c, "Acer Nitro 5 AN515-58", ALC287_FIXUP_ACER_MICMUTE_LED),
             	SND_PCI_QUIRK(0x1025, 0x1597, "Acer Nitro 5 AN517-55", ALC2XX_FIXUP_HEADSET_MIC),
             	SND_PCI_QUIRK(0x1025, 0x159e, "Acer Nitro 5 AN515-46", ALC2XX_FIXUP_HEADSET_MIC),
             	SND_PCI_QUIRK(0x1025, 0x160e, "Acer PT316-51S", ALC2XX_FIXUP_HEADSET_MIC),
            +	SND_PCI_QUIRK(0x1025, 0x1616, "Acer Aspire A515-57G", ALC256_FIXUP_ACER_HEADSET_MIC),
             	SND_PCI_QUIRK(0x1025, 0x161f, "Acer S40-54", ALC256_FIXUP_ACER_MIC_NO_PRESENCE),
             	SND_PCI_QUIRK(0x1025, 0x1640, "Acer Aspire A315-44P", ALC256_FIXUP_ACER_SFG16_MICMUTE_LED),
             	SND_PCI_QUIRK(0x1025, 0x1679, "Acer Nitro 16 AN16-41", ALC2XX_FIXUP_HEADSET_MIC),
          '';
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
