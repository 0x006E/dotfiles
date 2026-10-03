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

        # Second account. Its desktop lives in a rootless distrobox
        # container (modules/desktop/guest-desktop), so nothing graphical is
        # installed for it on the host. This block is only the account itself:
        # the name and the sops-sourced password. The groups the guest needs
        # live with the module that owns what this account may do, because
        # listing a group in both places concatenates the two lists.
        #
        # No `networkmanager` group: that group gets a blanket polkit yes over
        # every NetworkManager action, including reading the owner's stored
        # Wi-Fi passwords.
        users.guest = {
          isNormalUser = true;
          hashedPasswordFile = config.sops.secrets."passwords/guest".path;
        };
      };
    };
}
