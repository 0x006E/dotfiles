{ delib, pkgs, ... }:
delib.module {
  name = "services.system-services";
  options = delib.singleEnableOption true;

  nixos.ifEnabled = { ... }: {
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
