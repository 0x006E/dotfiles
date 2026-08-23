{ delib, ... }:
delib.module {
  name = "core.environment";

  nixos.always =
    { ... }:
    {
      pkgs,
      ...
    }:
    {
      documentation = {
        enable = true;
        doc.enable = false;
        info.enable = false;
      };
      i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];
      environment = {
        defaultPackages = [ ];
        systemPackages = with pkgs; [
          distrobox
          wireguard-tools
          proton-vpn
          pciutils
          usbutils
          lm_sensors
          powertop
          commit-mono
          vim
          kvmtool
          wget
          rsync
          strace
          libnotify
          git-crypt
          devenv
          wl-clipboard
          wayland-utils
          libsecret
          deluge
          shotwell
        ];
        sessionVariables = {
          VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json";
          NIXOS_OZONE_WL = "1";
          EDITOR = "nvim";
          WLR_NO_HARDWARE_CURSORS = "1";
          QT_QPA_PLATFORM = "wayland";
          NH_NO_CHECKS = 1;
        };
      };
    };
}
