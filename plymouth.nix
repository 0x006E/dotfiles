{
  config,
  pkgs,
  ...
}: {
  boot.kernelParams = [
    "quiet"
    "udev.log_level=0"
  ];
  boot.initrd.verbose = false;
  boot.consoleLogLevel = 0;

  boot.plymouth = {
    enable = true;
    theme = "rings";
    themePackages = [(pkgs.adi1090x-plymouth-themes.override {selected_themes = ["rings"];})];
  };

  environment.systemPackages = with pkgs; [
    plymouth
  ];
}
