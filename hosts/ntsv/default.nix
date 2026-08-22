{ delib, ... }:
delib.host {
  name = "ntsv";

  rice = "dark";
  type = "desktop";

  # Feature manifest: every module converted to delib.singleEnableOption
  # is toggled here explicitly. Modules without entries below are pure
  # infrastructure and stay unconditional (config/*, core/*, services.sops).
  myconfig = {
    hardware = {
      audio.enable = true;
      base.enable = true;
      kanata.enable = true;
      nvidia.enable = true;
      power.enable = true;
    };

    services = {
      desktop-services.enable = true;
      printing.enable = true;
      system-services.enable = true;
      virtualization.enable = true;
      wgcf.enable = true;
    };

    programs = {
      agentic.enable = true;
      apps.enable = true;
      browser.enable = true;
      cli.enable = true;
      gpg.enable = true;
      ide.enable = true;
      media.enable = true;
      system.enable = true;
      wayprompt.enable = true;
    };

    desktop = {
      fonts.enable = true;
      kanshi.enable = true;
      niri.enable = true;
      noctalia.enable = true;
      specialization.enable = true;
      stylix.enable = true;
      user-services.enable = true;
    };
  };
}
