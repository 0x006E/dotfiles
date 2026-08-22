{ delib, inputs, ... }:
delib.module {
  name = "services.sops";

  nixos.always =
    { myconfig, ... }:
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];

      sops = {
        defaultSopsFile = ../../secrets/secrets.yaml;
        defaultSopsFormat = "yaml";
        age.keyFile = "/var/lib/sops-nix/key.txt";
      };
    };
}
