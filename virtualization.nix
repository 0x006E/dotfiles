{
  config,
  pkgs,
  ...
}: {
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  services.qemuGuest.enable = true;
  services.spice-webdavd.enable = true;

  users.groups.libvirtd.members = ["nithin"];
}
