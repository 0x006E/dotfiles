{ delib, ... }:
delib.module {
  name = "programs.system";
  options = delib.singleEnableOption true;

  nixos.ifEnabled = { myconfig, ... }: {
    programs = {
      corectrl.enable = true;
      nix-index-database.comma.enable = true;

      nix-index = {
        enable = true;
        enableBashIntegration = true;
      };

      nh = {
        enable = true;
        clean = {
          enable = true;
          extraArgs = "--keep-since 3d --keep 3";
        };
        flake = "/home/${myconfig.constants.username}/nix";
      };
    };
  };
}
