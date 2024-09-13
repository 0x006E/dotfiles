{
  config,
  pkgs,
  ...
}: {
  services.fprintd = {
    enable = true;
  };
  environment.systemPackages = with pkgs; [(callPackage ./fprintd-tod.nix {})];
}
