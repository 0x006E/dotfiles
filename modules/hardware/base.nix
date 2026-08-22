{ delib, ... }:
delib.module {
  name = "hardware.base";
  options = delib.singleEnableOption true;

  nixos.ifEnabled = { ... }: {
    hardware = {
      uinput.enable = true;
      cpu.intel.updateMicrocode = true;
    };
  };
}
