{
  config,
  pkgs,
  ...
}:
{
  # Virtualization Services
  virtualisation = {
    # QEMU/KVM Configuration
    libvirtd.enable = true;
    spiceUSBRedirection.enable = true;

    # Container Systems
    docker.enable = true;
    incus.enable = true;
  };

  # Virtual Machine Management
  programs.virt-manager.enable = true;

  # Guest Services
  services = {
    qemuGuest.enable = true;
    spice-webdavd.enable = true;
  };

  # Network Configuration
  networking = {
    nftables.enable = true;
    firewall.trustedInterfaces = [ "virbr0" ];
  };

  # User Permissions
  users.users.nithin.extraGroups = [
    "libvirtd" # KVM/QEMU management
    "incus-admin" # Incus container management
    "docker" # Docker container access
  ];

  # Required Packages
  environment.systemPackages = with pkgs; [
    virtiofsd # VirtioFS daemon for enhanced filesystem sharing
  ];
}
