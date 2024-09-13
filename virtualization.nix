{ config, pkgs, ... }:
{
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  services.qemuGuest.enable = true;
  services.spice-webdavd.enable = true;
  virtualisation.incus.enable = true;
  virtualisation.docker.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
  networking.nftables.enable = true;
  networking.firewall.trustedInterfaces = [ "virbr0" ];
  users.users.nithin.extraGroups = [
    "libvirtd"
    "incus-admin"
    "docker"
  ]; # Enable ‘sudo’ for the user.
  environment.systemPackages = with pkgs; [ virtiofsd ];
}
