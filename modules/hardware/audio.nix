{ delib, inputs, ... }:
delib.module {
  name = "hardware.audio";

  nixos.always = { myconfig, ... }: { pkgs, config, lib, ... }: {
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
          "monitor.bluez.properties" = {
            "bluez5.enable-sbc-xq" = true;
            "bluez5.enable-msbc" = true;
            "bluez5.enable-hw-volume" = true;
            "bluez5.roles" = [
              "hsp_hs"
              "hsp_ag"
              "hfp_hf"
              "hfp_ag"
            ];
          };
        };
      };
    };
    services.speechd.enable = pkgs.lib.mkForce false;
  };
}
