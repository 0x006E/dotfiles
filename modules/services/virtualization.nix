{ delib, pkgs, ... }:
delib.module {
  name = "services.virtualization";
  options = delib.singleEnableOption true;

  nixos.ifEnabled =
    { myconfig, cfg, ... }:
    let
      inherit (myconfig.constants) username;
    in
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

      users.users.${username}.extraGroups = [
        "libvirtd"
        "docker"
      ];

      environment.systemPackages = with pkgs; [
        virtiofsd
      ];
    };
}
