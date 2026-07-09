{ delib, inputs, ... }:
delib.module {
  name = "services.system-services";

  nixos.always =
    { myconfig, ... }:
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      services = {
        fwupd.enable = true;
        bpftune.enable = true;

        scx = {
          enable = true;
          package = pkgs.scx.full;
          scheduler = "scx_lavd";
          extraArgs = [ "--autopower" ];
        };

        beesd.filesystems = {
          "-" = {
            spec = "/dev/mapper/crypted";
            hashTableSizeMB = 2048;
            extraOptions = [
              "--loadavg-target"
              "5.0"
            ];
          };
        };
      };
    };
}
