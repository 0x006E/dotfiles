{
  delib,
  inputs,
  ...
}:
delib.module {
  name = "desktop.look";
  options = delib.singleEnableOption true;

  nixos.always = {
    imports = [ inputs.look.nixosModules.default ];
  };

  home.always = {
    imports = [ inputs.look.homeModules.default ];
  };

  nixos.ifEnabled = { ... }: {
    programs.lookapp.enable = true;
  };

  home.ifEnabled =
    { ... }:
    {
      imports = [
        (
          { config, ... }:
          {
            programs.lookapp = {
              enable = true;
              package = null; # Installed system-wide via nixosModule
              theme = "custom";
              settings = {
                ui_tint_red = config.lib.stylix.colors.base00-dec-r;
                ui_tint_green = config.lib.stylix.colors.base00-dec-g;
                ui_tint_blue = config.lib.stylix.colors.base00-dec-b;
                ui_tint_opacity = 0.92;

                ui_font_red = config.lib.stylix.colors.base05-dec-r;
                ui_font_green = config.lib.stylix.colors.base05-dec-g;
                ui_font_blue = config.lib.stylix.colors.base05-dec-b;
                ui_font_opacity = 1.0;

                ui_border_red = config.lib.stylix.colors.base03-dec-r;
                ui_border_green = config.lib.stylix.colors.base03-dec-g;
                ui_border_blue = config.lib.stylix.colors.base03-dec-b;
                ui_border_opacity = 0.5;
                ui_border_thickness = 2.0;

                ui_font_name = config.stylix.fonts.monospace.name;
                ui_compositor_blur = false;

                launcher_hotkey = "none";
                terminal = "ghostty";
                code_editor = "nvim";
                text_editor = "nvim";
                file_manager = "nautilus";
              };
            };
          }
        )
      ];
    };
}
