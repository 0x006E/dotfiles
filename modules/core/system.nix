{ delib, ... }:
delib.module {
  name = "core.system";

  nixos.always =
    { myconfig, ... }:
    {
      ...
    }:
    let
      # denix passes the manifest as the outer function's argument; the flake's
      # specialArgs do not include myconfig, so it cannot come from the inner
      # (module-args) lambda.
      inherit (myconfig.constants) username;
    in
    {
      systemd = {
        settings.Manager = {
          DefaultTimeoutStopSec = "10s";
        };
        user.settings.Manager = {
          DefaultTimeoutStopSec = "10s";
        };
        sleep.settings.Sleep = {
          MemorySleepMode = "deep";
        };
      };

      security = {
        rtkit.enable = true;
        pam.services.hyprlock = { };

        # The owner's login sessions may lock up to 64 MiB.
        #
        # QEMU 10.1+ treats a failed io_uring_setup() as fatal, and since Linux
        # 6.14 the ring pages are charged against the caller's RLIMIT_MEMLOCK
        # again. With the 8 MiB default, an unprivileged qemu therefore dies
        # immediately with "Failed to initialize io_uring: Cannot allocate
        # memory" -- including qemu-img, and therefore `nixos-rebuild build-vm`
        # and friends. A hard limit can only be raised by a privileged process,
        # so this has to be a PAM limit: getty, `su` and the greeter's post_auth
        # all run the `login` stack as root before dropping privileges, and that
        # is the last chance to lift it.
        #
        # 64 MiB is generous for what it is for (a handful of io_uring rings),
        # and unlike "unlimited" it stays a real limit.
        #
        # Only login sessions. System and user services get theirs from systemd
        # (LimitMEMLOCK= in the unit) instead.
        pam.loginLimits = [
          {
            domain = username;
            type = "hard";
            item = "memlock";
            value = "65536"; # KiB
          }
          {
            domain = username;
            type = "soft";
            item = "memlock";
            value = "65536"; # KiB
          }
        ];
      };

      time = {
        timeZone = "Asia/Kolkata";
        hardwareClockInLocalTime = true;
      };

      system.stateVersion = "24.05";
    };
}
