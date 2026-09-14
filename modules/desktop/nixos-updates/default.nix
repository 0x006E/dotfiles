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
        "noctalia/plugins/nixos-updates/service.luau".source = ./service.luau;
        "noctalia/plugins/nixos-updates/panel.luau".source = ./panel.luau;
        "noctalia/plugins/nixos-updates/lib/helpers.luau".source = ./lib/helpers.luau;
        "noctalia/plugins/nixos-updates/translations/en.json".source = ./translations/en.json;
      };

      programs.noctalia.settings = {
        plugins.enabled = [ "ntsv/nixos-updates" ];
        # Plugin-level settings (see [[setting]] in plugin.toml), read
        # via noctalia.getConfig in the entries.
        plugin_settings."ntsv/nixos-updates" = {
          flake_path = "/home/${myconfig.constants.username}/nix";
          poll_minutes = 30;
          dotfiles_repo = "0x006E/dotfiles";
          max_inputs = 12;
        };
        widget.nixos_updates = {
          type = "ntsv/nixos-updates:updates";
        };
      };
    };
}
