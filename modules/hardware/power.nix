{ delib, inputs, ... }:
delib.module {
  name = "hardware.power";

  nixos.always =
    { myconfig, ... }:
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      imports = [ inputs.battery-notifier.nixosModules.default ];
      powerManagement = {
        enable = true;
        powertop.enable = false;
      };
      services.battery-notifier = {
        enable = true;
        settings = {
          interval_ms = 3000;
          reminder = {
            threshold = 30;
          };
          threat = {
            threshold = 20;
          };
          warn = {
            threshold = 25;
          };
        };
      };
      services.thermald.enable = true;
      services.power-profiles-daemon.enable = false;
      services.auto-cpufreq = {
        enable = true;
        settings = {
          battery = {
            governor = "powersave";
            turbo = "never";
            energy_perf_bias = "power";
            energy_performance_preference = "power";
          };
          charger = {
            governor = "performance";
            turbo = "auto";
          };
        };
      };
      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="pci", DRIVER=="pcieport", ATTR{power/wakeup}="disabled"

        ACTION=="add", SUBSYSTEM=="usb", TEST=="power/autosuspend", ATTR{idVendor}=="17ef", ATTR{idProduct}=="60ff", ATTR{power/autosuspend}="0"
        ACTION=="add", SUBSYSTEM=="usb", TEST=="power/autosuspend_delay_ms", ATTR{idVendor}=="17ef", ATTR{idProduct}=="60ff", ATTR{power/autosuspend_delay_ms}="0"
        ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{idVendor}=="17ef", ATTR{idProduct}=="60ff", ATTR{power/control}="on"

        ACTION=="add", SUBSYSTEM=="usb", TEST=="power/autosuspend", ATTR{idVendor}=="1ea7", ATTR{idProduct}=="0066", ATTR{power/autosuspend}="0"
        ACTION=="add", SUBSYSTEM=="usb", TEST=="power/autosuspend_delay_ms", ATTR{idVendor}=="1ea7", ATTR{idProduct}=="0066", ATTR{power/autosuspend_delay_ms}="0"
        ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{idVendor}=="1ea7", ATTR{idProduct}=="0066", ATTR{power/control}="on"

        SUBSYSTEM=="pci", ATTR{power/control}="auto"
      '';
    };
}
