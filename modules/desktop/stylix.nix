{
  delib,
  inputs,
  pkgs,
  ...
}:
delib.module {
  name = "desktop.stylix";
  options = delib.singleEnableOption true;

  nixos.always = {
    imports = [ inputs.stylix.nixosModules.stylix ];
  };

  nixos.ifEnabled = { ... }: {
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

  home.ifEnabled = { myconfig, ... }: {
    stylix.targets.zen-browser.profileNames = [ myconfig.constants.username ];
  };
}
