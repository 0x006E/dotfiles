{ delib, ... }:
delib.module {
  name = "services.system-services";
  options = delib.singleEnableOption true;

  nixos.ifEnabled = { ... }: {
    services = {
      fwupd.enable = true;
      bpftune.enable = true;

      scx-loader = {
        enable = true;
        config = {
          default_sched = "scx_lavd";
          scheds.scx_lavd.auto_mode = [ "--autopower" ];
        };
      };

      beesd.filesystems = {
        "-" = {
          spec = "/dev/mapper/crypted";
          hashTableSizeMB = 256;
          extraOptions = [
            "--loadavg-target"
            "5.0"
          ];
        };
      };
    };
  };
}
