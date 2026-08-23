{ delib, ... }:
delib.module {
  name = "user";

  # If you're not using NixOS, you can remove this entire block.
  nixos.always =
    { myconfig, ... }:
    {
      config,
      pkgs,
      ...
    }:
    let
      inherit (myconfig.constants) username;
    in
    {
      # Passwords live in sops so they survive the ephemeral root.
      # Generate with: openssl passwd -6 (add via `sops secrets/secrets.yaml`)
      users.mutableUsers = false;

      sops.secrets."passwords/nithin".neededForUsers = true;
      sops.secrets."passwords/guest".neededForUsers = true;

      users = {
        groups.${username} = { };

        users.${username} = {
          isNormalUser = true;
          hashedPasswordFile = config.sops.secrets."passwords/nithin".path;
          extraGroups = [ "wheel" ];
        };

        users.guest = {
          isNormalUser = true;
          hashedPasswordFile = config.sops.secrets."passwords/guest".path;
          extraGroups = [
            "networkmanager"
            "video"
            "audio"
          ];
          packages = with pkgs; [
            firefox
            libreoffice
            vlc
          ];
        };
      };
    };
}
