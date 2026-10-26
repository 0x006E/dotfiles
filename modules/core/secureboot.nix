{ delib, ... }:
delib.module {
  name = "core.secureboot";

  nixos.always = { ... }: { pkgs, lib, ... }: {
    boot = {
      # Disable systemd-boot as it's replaced by Lanzaboote
      loader.systemd-boot.enable = lib.mkForce false;

      # systemd in initrd is the only initrd implementation since the
      # scripted one was removed, and it is enabled by default.

      # Lanzaboote Configuration
      lanzaboote = {
        enable = true;
        pkiBundle = "/etc/secureboot";
        measuredBoot = {
          enable = true;
          pcrs = [
            0
            4
            7
          ];
        };
        settings = {
          reboot-for-bitlocker = true; # Enable BitLocker compatibility
        };
      };
    };

    # Required Tools
    environment.systemPackages = [
      pkgs.sbctl # Secure Boot key management and signing utility
    ];
  };
}
