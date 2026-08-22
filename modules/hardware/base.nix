{ delib, ... }:
delib.module {
  name = "hardware.base";

  nixos.always =
    { ... }:
    {
      ...
    }:
    {
      hardware = {
        uinput.enable = true;
        cpu.intel.updateMicrocode = true;
      };
    };
}
