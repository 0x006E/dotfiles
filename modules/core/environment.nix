{ delib, ... }:
delib.module {
  name = "core.environment";

  nixos.always = { myconfig, ... }: { pkgs, config, lib, ... }: {
    environment = {
      systemPackages = with pkgs; [
        distrobox
        wireguard-tools
        protonvpn-gui
        pciutils
        usbutils
        lm_sensors
        powertop
        commit-mono
        vim
        kvmtool
        xwayland
        wget
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
