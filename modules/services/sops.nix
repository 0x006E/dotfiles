{ delib, inputs, ... }:
delib.module {
  name = "services.sops";

  nixos.always =
    { ... }:
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];

      sops = {
        defaultSopsFile = ../../secrets/secrets.yaml;
        defaultSopsFormat = "yaml";
        # Physical path on the persisted subvolume: neededForUsers secrets are
        # decrypted during initrd activation, before impermanence's stage-2
        # bind mounts exist. /persist is neededForBoot, so this works.
        age.keyFile = "/persist/var/lib/sops-nix/key.txt";
      };
    };
}
