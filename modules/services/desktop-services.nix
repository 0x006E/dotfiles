{
  delib,
  inputs,
  pkgs,
  ...
}:
delib.module {
  name = "services.desktop-services";
  options = delib.singleEnableOption true;

  nixos.always = {
    imports = [ inputs.noctalia-greeter.nixosModules.default ];
  };

  nixos.ifEnabled = { ... }: {
    services = {
      gnome.gcr-ssh-agent.enable = false;
      libinput.enable = true;
    };

    programs.dconf.enable = true;
    programs.sway.enable = true;

    # Greeter: matches the Noctalia shell. Lists niri (default) and sway
    # from wayland-sessions; accounts-daemon is enabled by the module for
    # user avatars.
    programs.noctalia-greeter = {
      enable = true;
      settings = {
        keyboard.layout = "us";
        cursor = {
          theme = "catppuccin-mocha-light-cursors";
          size = 24;
          path = "${pkgs.catppuccin-cursors.mochaLight}/share/icons";
        };
      };
    };
  };
}
