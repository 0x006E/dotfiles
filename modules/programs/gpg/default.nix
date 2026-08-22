{ delib, ... }:
delib.module {
  name = "programs.gpg";
  options = delib.singleEnableOption true;

  home.ifEnabled = { myconfig, cfg, ... }: {
    programs.gpg = {
      enable = true;
      publicKeys = [
        {
          source = ./public.asc;
          trust = 5;
        }
      ];
    };
    services.gpg-agent = {
      enable = true;
      enableExtraSocket = true;
      enableSshSupport = true;
    };
  };
}
