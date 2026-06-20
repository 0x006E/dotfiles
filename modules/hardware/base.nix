{ delib, ... }:
delib.module {
  name = "hardware.base";

  nixos.always = { myconfig, ... }: { pkgs, config, lib, ... }: {
    hardware = {
      uinput.enable = true;
      cpu.intel.updateMicrocode = true;
    };
  };
}
