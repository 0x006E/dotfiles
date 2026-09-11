{
  delib,
  config,
  pkgs,
  ...
}:
delib.module {
  name = "hardware.audio";
  options = delib.singleEnableOption true;

  nixos.ifEnabled = { ... }: {
    security.rtkit.enable = true;
    services.pulseaudio.enable = false;
    services.pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
      wireplumber = {
        package = pkgs.wireplumber;
        extraConfig = {
          "disable-camera" = {
            "wireplumber.profiles".main."monitor.libcamera" = "disabled";
          };
          "10-bluez" = {
            "monitor.bluez.properties" = {
              "bluez5.enable-sbc-xq" = true;
              "bluez5.enable-msbc" = true;
              "bluez5.enable-hw-volume" = true;
              "bluez5.roles" = [
                "a2dp_sink"
                "a2dp_source"
                "bap_sink"
                "bap_source"
                "hsp_hs"
                "hsp_ag"
                "hfp_hf"
                "hfp_ag"
              ];
            };
          };
        };
      };
    };
    services.speechd.enable = pkgs.lib.mkForce false;
    # Out-of-tree snd-hda-codec-alc269 carrying the Acer quirk, built like
    # pkgs/uvcvideo-kernel-module (same-name override via updates/).
    boot.extraModulePackages = [
      (config.boot.kernelPackages.callPackage ../../pkgs/alc269-kernel-module { })
    ];
    # Guardrail for WirePlumber's recurring memory leak (3.3G RSS + 15G swap
    # observed; regrew 32M -> 685M in 36min after restart). The base unit
    # already has Restart=on-failure, so hitting the cap restarts audio
    # instead of sinking the machine.
    systemd.user.services.wireplumber.serviceConfig = {
      MemoryMax = "1G";
    };
  };
}
