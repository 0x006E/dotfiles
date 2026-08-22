{ delib, ... }:
delib.module {
  name = "services.virtualization";

  nixos.always =
    { myconfig, ... }:
    {
      pkgs,
      ...
    }:
    {
      virtualisation = {
        libvirtd.enable = true;
        spiceUSBRedirection.enable = true;
        docker.enable = true;
        waydroid.enable = true;
      };

      programs.virt-manager.enable = true;

      services = {
        qemuGuest.enable = true;
        spice-webdavd.enable = true;
      };

      networking = {
        nftables.enable = true;
        firewall.trustedInterfaces = [ "virbr0" ];
      };

      users.users.${myconfig.constants.username}.extraGroups = [
        "libvirtd"
        "docker"
      ];

      environment.systemPackages = with pkgs; [
        virtiofsd
      ];
    };
}
