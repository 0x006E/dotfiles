{
  config,
  pkgs,
  ...
}:
{

  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.wayprompt.overrideAttrs (old: {
      postPatch = ''
        substituteInPlace src/wayprompt-pinentry.zig \
          --replace-fail 'D {s}\nEND\nOK\n' 'D {s}\nOK\n'
      '';
    });
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
