{ delib, ... }:
delib.module {
  name = "hardware.bluetooth";
  options = delib.singleEnableOption true;

  nixos.ifEnabled = { ... }: {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    services.blueman.enable = true;
  };
}
