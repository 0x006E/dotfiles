{ delib, inputs, ... }:
delib.module {
  name = "services.virtualization";

  nixos.always = { myconfig, ... }: { pkgs, config, lib, ... }: {
    virtualisation = {
      libvirtd.enable = true;
      spiceUSBRedirection.enable = true;
      docker.enable = true;
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

    users.users.nithin.extraGroups = [
      "libvirtd"
      "docker"
    ];

    environment.systemPackages = with pkgs; [
      virtiofsd
    ];
  };
}
