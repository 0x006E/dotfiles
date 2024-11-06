{
  config,
  pkgs,
  ...
}:
{
  boot = {
    # Kernel Parameters for Boot Behavior
    kernelParams = [
      # Silent Boot Parameters
      "quiet" # Silences general boot messages
      "splash" # Enable splash screen
      "bgrt_disable" # Disable BGRT (Boot Graphics Resource Table)

      # Systemd and udev Logging Controls
      "rd.systemd.show_status=false" # Silence successful systemd messages in initrd
      "rd.udev.log_level=3" # Minimize initrd udev logging
      "udev.log_priority=3" # Minimize general udev logging

      # Emergency Access
      "boot.shell_on_fail" # Provide debug shell on boot failure
    ];

    # Additional Boot Settings
    initrd.verbose = false; # Disable verbose initrd messages
    consoleLogLevel = 0; # Minimize console output

    # Plymouth Configuration
    plymouth.enable = true; # Enable Plymouth boot splash
  };

  # Required Packages
  environment.systemPackages = with pkgs; [
    plymouth
  ];
}
