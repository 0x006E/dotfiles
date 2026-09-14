{ delib, ... }:
delib.module {
  name = "desktop.nixos-updates";
  options = delib.singleEnableOption true;

  home.ifEnabled =
    { myconfig, ... }:
    {
      # Noctalia discovers hand-placed plugins under
      # ~/.local/share/noctalia/plugins/<plugin>/ as its built-in local
      # source; enabling the id below activates the widget.
      xdg.dataFile = {
        "noctalia/plugins/nixos-updates/plugin.toml".source = ./plugin.toml;
        "noctalia/plugins/nixos-updates/widget.luau".source = ./widget.luau;
      };

      programs.noctalia.settings = {
        plugins.enabled = [ "ntsv/nixos-updates" ];
        # Entry settings land on the widget instance table, which is what
        # noctalia.getConfig reads (see widget.luau cfg()).
        widget.nixos_updates = {
          type = "ntsv/nixos-updates:updates";
          flake_path = "/home/${myconfig.constants.username}/nix";
          poll_minutes = 30;
          dotfiles_repo = "0x006E/dotfiles";
        };
      };
    };
}
