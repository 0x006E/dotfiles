# Guest-side bits for the test VM. The module under test supplies the session
# dispatcher, the greeter entry, podman and the login hook; this file is only
# what a throwaway VM needs on top of that, plus what the real host would get
# from modules it deliberately leaves out (hardware, secrets, greeter).
{
  pkgs,
  ...
}:
{
  # virtio_gpu is the DRM driver the container's compositor will use;
  # fuse is what fuse-overlayfs (the pinned storage driver) needs.
  boot.kernelModules = [
    "virtio_gpu"
    "fuse"
  ];

  hardware.graphics.enable = true;

  # What the guest does need is a *single* DRM device. QEMU adds a default
  # -vga std (bochs-drm) unless told otherwise, which appears as a second
  # /dev/dri/cardN -- hence -vga none in vm-up.sh's qemu invocation.
  hardware.uinput.enable = true;

  security.polkit.enable = true;

  # The QEMU guest agent. This is what makes the VM scriptable without the
  # serial console: guest-exec runs a command in the guest and returns its
  # stdout/stderr/exit code over QMP, so there is no base64-over-a-pty, no
  # quoting hell, and no virtiofs staging. It starts on udev seeing the
  # org.qemu.guest_agent.0 virtio port, which vm-up.sh adds to the QEMU
  # command line. Serial stays for early boot (the agent starts late).
  services.qemuGuest.enable = true;

  # No greeter and no display manager: greetd needs wlroots and the real session
  # entrypoints, and neither is what this VM tests. What it tests is that the
  # dispatcher picks the right branch for each user and that the login hook
  # fires exactly when it should -- and both can be driven from a TTY, which is
  # also the only way to test the hook without logging out of a live desktop.
  #
  # Deliberately no autologin: it would start a second session on the serial
  # console too, and two of them would fight over one container.
  services.getty.autologinUser = null;

  # The guest account, without sops: the real one comes from
  # modules/config/user.nix, which needs the age key. The module under test adds
  # the shell and the extra groups.
  users.users.guest = {
    isNormalUser = true;
    password = "guest";
  };

  # A stand-in for the owner, so the dispatcher's owner branch is reachable and
  # the isolation claim is testable: same name, same 0700 home, one file in it
  # that the guest must not be able to read.
  users.users.nithin = {
    isNormalUser = true;
    password = "nithin";
    home = "/home/nithin";
    homeMode = "0700";
  };

  # Test-only, and only because the box's polkit rule and the guest's DAC
  # limits are worth being able to poke at from a root shell when a test fails.
  users.users.root.password = "root";
  system.activationScripts.guestDesktopTestOwner = {
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

  # Let the container engine read the certificate store for its image pull.
  networking.nameservers = [ "1.1.1.1" ];

  # The disk is not optional: the GNOME image is ~2 GB and podman stages it in
  # /var/tmp, on top of the image itself. The default qemu-vm root filesystem
  # fills up mid-install.
  virtualisation.diskSize = 16384;
  virtualisation.memorySize = 4096;
  virtualisation.cores = 4;
  virtualisation.graphics = false;
}
