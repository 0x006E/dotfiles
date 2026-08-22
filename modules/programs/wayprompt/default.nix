{ delib, pkgs-stable, config, ... }:
delib.module {
  name = "programs.wayprompt";
  options = delib.singleEnableOption true;

  home.ifEnabled = { myconfig, cfg, ... }: {
    services.gpg-agent = {
      enable = true;
      # TODO: return to pkgs.wayprompt once nixpkgs unstable fixes the
      # zig 0.13 / zig-wayland regeneration breakage.
      pinentry.package = pkgs-stable.wayprompt.overrideAttrs (_old: {
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
  };
}
