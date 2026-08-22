{ delib, inputs, ... }:
delib.module {
  name = "desktop.stylix";

  nixos.always =
    { myconfig, ... }:
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      imports = [ inputs.stylix.nixosModules.stylix ];
      stylix = {
        enable = true;
        fonts = {
          monospace = {
            package = pkgs.nerd-fonts.commit-mono;
            name = "CommitMono Nerd Font";
          };
        };
        targets.qt.enable = false;
      };

      # Silent boot / Plymouth lives in core.plymouth.
    };

  home.always =
    { myconfig, ... }:
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      stylix.targets.zen-browser.profileNames = [ myconfig.constants.username ];
    };
}
