{ delib, ... }:
delib.module {
  name = "user";

  # If you're not using NixOS, you can remove this entire block.
  nixos.always =
    { myconfig, ... }:
    {
      config,
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
          extraGroups = [
            "wheel"
            "networkmanager"
          ];
        };

        # Kiosk account. Its whole session is the Ubuntu MATE box --
        # modules/services/guest-box sets `shell` to the box session, so getty
        # logins and the greeter session entry both land there. No
        # `networkmanager` group: that group gets a blanket polkit yes over
        # every NetworkManager action, including reading the owner's stored
        # Wi-Fi passwords; services.guest-box grants the guest the handful of
        # actions the desktop actually needs instead. No host `packages`
        # either: everything a guest runs lives in the box.
        users.guest = {
          isNormalUser = true;
          hashedPasswordFile = config.sops.secrets."passwords/guest".path;
          extraGroups = [
            "video"
            "audio"
          ];
        };
      };
    };
}
