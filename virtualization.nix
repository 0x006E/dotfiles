{
  config,
  pkgs,
  ...
}: {
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  services.qemuGuest.enable = true;
  services.spice-webdavd.enable = true;
  virtualisation.incus.enable = true;
  virtualisation.docker.enable = true;
  networking.nftables.enable = true;
  users.users.nithin. extraGroups = ["libvirtd" "incus-admin"]; # Enable ‘sudo’ for the user.
}
