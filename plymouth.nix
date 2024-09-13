{
  config,
  pkgs,
  ...
}: {
  boot.kernelParams = [
    # Silences boot messages
    "quiet"
    # Show a splash screen
    "splash"

    "bgrt_disable"
    # Silences successfull systemd messages from the initrd
    "rd.systemd.show_status=false"
    # Silence systemd version number in initrd
    "rd.udev.log_level=3"
    # Silence systemd version number
    "udev.log_priority=3"
    # If booting fails drop us into a shell where we can investigate
    "boot.shell_on_fail"
  ];
  boot.initrd.verbose = false;
  boot.consoleLogLevel = 0;

  boot.plymouth = let
    theme = "deus_ex";
  in {
    enable = true;
    inherit theme;
    themePackages = [(pkgs.adi1090x-plymouth-themes.override {selected_themes = [theme];})];
  };

  environment.systemPackages = with pkgs; [plymouth];
}
