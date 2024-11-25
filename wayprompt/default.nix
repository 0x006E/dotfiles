{
  config,
  pkgs,
  ...
}:
{

  services.gpg-agent = {
    enable = true;
    pinentryPackage = pkgs.wayprompt;
  };
  home.file.".config/wayprompt/config.ini".source =
    let
      configFile = config.lib.stylix.colors {
        template = ./config.ini.mustache;
        extension = ".ini";
      };
    in
    "${configFile}";
}
