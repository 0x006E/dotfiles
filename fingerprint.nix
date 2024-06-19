{
  config,
  pkgs,
  ...
}: let
  fprintd-tod = import ./fprintd-tod.nix;
in {
  services.fprintd = {
    enable = true;
  };
  environment.systemPackages = [
    fprintd-tod
  ];
}
