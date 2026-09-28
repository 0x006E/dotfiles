# Guest-side bits for the test VM. The module under test supplies the box, the
# session script, podman, tmpfiles and the polkit rule; this file is only what a
# throwaway VM needs on top of that, plus what the real host would get from
# modules it deliberately leaves out (hardware, desktop, secrets, greeter).
{
  pkgs,
  ...
}:
{
  # virtio-gpu needs the DRM driver; fuse is what fuse-overlayfs (the box's
  # storage driver) needs for /dev/fuse.
  boot.kernelModules = [
    "virtio_drm"
    "fuse"
  ];

  hardware.uinput.enable = true;

  # The polkit rule under test only does anything with polkitd running.
  security.polkit.enable = true;

  # No greeter in the VM: greetd needs wlroots and the real session entrypoints
  # are verified on the laptop. The guest's *login shell* is the thing this VM
  # exercises, and logging in at the tty1 prompt runs exactly that shell.
  #
  # Deliberately no autologin: it would start a second guest session on the
  # serial console too, and two of them fight over one box (same container
  # name, same wiped HOME). vm-up.sh logs in by typing at the tty1 prompt.
  services.getty.autologinUser = null;

  # The guest account, without sops: the real one comes from modules/config/user.nix,
  # which needs the age key. Everything else about it -- the shell being the box
  # session -- comes from the module under test.
  users.users.guest = {
    isNormalUser = true;
    password = "guest";
    extraGroups = [
      "video"
      "audio"
      "wheel" # only so the VM is debuggable from a console if a test needs it
    ];
  };

  # A stand-in for the owner, so the isolation claim is testable rather than
  # asserted: same name, same 0700 home, one file in it that the guest must not
  # be able to read. On the laptop this is the real account and real files.
  users.users.nithin = {
    isNormalUser = true;
    password = "nithin";
    home = "/home/nithin";
    homeMode = "0700";
  };
  # Test-only, and only because the box's polkit rule and the guest's DAC
  # limits are worth being able to poke at from a root shell when a test fails.
  users.users.root.password = "root";
  system.activationScripts.guestBoxTestOwner = {
    text = ''
      mkdir -p /home/nithin
      chown nithin:users /home/nithin
      chmod 0700 /home/nithin
      printf 'the owner does not want you reading this\n' >/home/nithin/private.txt
      chown nithin:users /home/nithin/private.txt
      chmod 0600 /home/nithin/private.txt
    '';
  };

  # Enough of a shell environment to debug a failed session by hand from the
  # VM console. Not part of the guest's real configuration.
  environment.systemPackages = with pkgs; [
    bash
    vim
  ];

  # Let the box's container engine read the certificate store for its image pull
  # and use a resolvable DNS server.
  networking.nameservers = [ "1.1.1.1" ];

  # The test image: same base, same package list, desktop already installed.
  # Built by ../make-test-image.sh inside the running VM, into the guest's own
  # rootless podman store -- which is the only place the box can find it.
  #
  # This is the *only* difference from production here. The launcher compares the
  # container's image against this option and rebuilds the box when they differ,
  # so switching back to docker.io/library/ubuntu:24.04 is one line and one
  # login.
  services.guest-box.image = "localhost/guest-box-test:24.04";

  # The guest's container storage lives in the guest's home here: the VM has no
  # impermanence, so there is no /persist/home/guest to bind. Fine for a test.
  #
  # The disk is not optional: the MATE desktop is ~300 MB installed and podman
  # stages that in /var/tmp, on top of the image itself. The default qemu-vm root
  # filesystem fills up mid-install.
  virtualisation.diskSize = 16384;
  virtualisation.memorySize = 4096;
  virtualisation.cores = 4;
  virtualisation.graphics = false;
}
