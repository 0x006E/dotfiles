{ delib, ... }:
delib.module {
  name = "core.secureboot";

  nixos.always = { ... }: { pkgs, lib, ... }: {
    boot = {
      # Disable systemd-boot as it's replaced by Lanzaboote
      loader.systemd-boot.enable = lib.mkForce false;

      # Enable systemd in initrd
      initrd.systemd.enable = true;

      # Lanzaboote Configuration
      lanzaboote = {
        enable = true;
        pkiBundle = "/etc/secureboot";
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
