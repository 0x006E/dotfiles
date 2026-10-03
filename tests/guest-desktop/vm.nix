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

  # A greeter, because the whole point of this VM is the greeter path.
  #
  # The first version of this file said "no greeter and no display manager:
  # greetd needs wlroots and neither is what this VM tests", and that omission
  # is precisely why a greetd-only bug survived all of it: greetd never sets
  # XDG_SESSION_ID, every probe run from a TTY or the agent socket set it by
  # hand, and the one mechanism that only works under greetd was never once
  # exercised. tuigreet is the cheapest client that still makes greetd run the
  # session as its own child, which is the property under test.
  services.greetd = {
    enable = true;
    settings = {
      terminal = {
        vt = 1;
      };
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --user nithin";
        user = "greeter";
      };
    };
  };

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

  # Record what the box actually receives, instead of only asserting that
  # gnome-session eventually failed. The failure that cost a hardware cycle
  # ("Failed to find any matching session") was invisible in every log because
  # the dispatcher's stderr goes to the greeter's screen and nothing recorded
  # the environment mutter would have seen.
  #
  # /home/guest is bind-mounted into the container, so a file written there from
  # inside the box is readable on the guest side, and the agent can fetch it.
  # That asserts the whole chain at once: greetd started the dispatcher as a
  # session child, the resolver derived the id from that session's scope,
  # distrobox forwarded it, and the box can see the session file it names.
  # gnome-session is not needed for any of that, which is what keeps this test
  # to a ~70 MB image instead of the 2 GB desktop.
  #
  # A real file rather than an inline `sh -c`: the payload is full of single
  # quotes and $VARs meant to expand inside the box, which shellcheck rightly
  # refuses to inline (SC2016), and which would be unreadable if it did.
  system.activationScripts.guestDesktopTestProbe = {
    text = ''
      mkdir -p /home/guest
      cat >/home/guest/dump-session-env.sh <<'PROBE'
      #!/bin/bash
      # Runs as the guest, inside the box, with the environment the dispatcher
      # handed to distrobox. Writes what it sees, then holds the session open so
      # the VM stays logged in while the result is collected.
      {
        echo "XDG_SESSION_ID=$XDG_SESSION_ID"
        echo "XDG_SESSION_TYPE=$XDG_SESSION_TYPE"
        echo "XDG_CURRENT_DESKTOP=$XDG_CURRENT_DESKTOP"
        echo "XDG_SESSION_DESKTOP=$XDG_SESSION_DESKTOP"
        echo "CONTAINER_ID=$CONTAINER_ID"
        echo "--- cgroup of this box process (shows the libpod scope, never a session)"
        cat /proc/self/cgroup
        echo "--- the session file XDG_SESSION_ID names, read from inside the box"
        cat "/run/systemd/sessions/$XDG_SESSION_ID" 2>&1
        echo "--- every session file visible in the box"
        ls /run/systemd/sessions 2>&1
        echo "--- is it a bind mount of the host's (not the box's own logind)?"
        mountpoint /run/systemd/sessions 2>&1
        echo "--- host system bus reachable from the box?"
        timeout 10 busctl --system --no-pager list 2>&1 | grep -c org.freedesktop.login1
      } >/home/guest/session-env.txt 2>&1
      sleep 3600
      PROBE
      chmod 0755 /home/guest/dump-session-env.sh
      chown guest:users /home/guest/dump-session-env.sh
    '';
  };

  services.guest-desktop.gnomeSessionCommand = "/home/guest/dump-session-env.sh";

  # The disk is not optional: the GNOME image is ~2 GB and podman stages it in
  # /var/tmp, on top of the image itself. The default qemu-vm root filesystem
  # fills up mid-install.
  virtualisation.diskSize = 16384;
  virtualisation.memorySize = 4096;
  virtualisation.cores = 4;
  virtualisation.graphics = false;
}
