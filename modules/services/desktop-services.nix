{
  delib,
  inputs,
  ...
}:
delib.module {
  name = "services.desktop-services";
  options = delib.singleEnableOption true;

  nixos.always = {
    imports = [ inputs.noctalia-greeter.nixosModules.default ];
  };

  nixos.ifEnabled = { myconfig, ... }: {
    services = {
      gnome.gcr-ssh-agent.enable = false;
      libinput.enable = true;
    };

    programs.dconf.enable = true;
    programs.sway.enable = true;

    # Greeter: matches the Noctalia shell. Lists niri (default) and sway
    # from wayland-sessions; accounts-daemon is enabled by the module for
    # user avatars.
    # Rice-specific appearance (cursor, theme mode, wallpaper) lives in
    # rices/*/default.nix; the day/night toggle keeps the greeter in sync
    # at runtime via `noctalia msg greeter-sync`.
    services.displayManager.noctalia-greeter = {
      enable = true;
      settings = {
        keyboard.layout = "us";
        # Single-user machine: open directly on the password step.
        user.default = myconfig.constants.username;
      };
    };
  };
}
