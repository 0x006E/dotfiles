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
      targets = {
        # Qt theming on: flameshot's annotation UI and the kdeconnect
        # indicator otherwise render stock-light on a dark desktop.
        # (Noctalia is QML self-themed and unaffected either way.)
        qt.enable = true;
      };
    };

    # Silent boot / Plymouth lives in core.plymouth.
  };

  home.ifEnabled = { myconfig, ... }: {
    stylix.targets.zen-browser.profileNames = [ myconfig.constants.username ];
  };
}
