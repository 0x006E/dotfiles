{
  config,
  pkgs,
  ...
}:
{
  services.fprintd = {
    enable = true;
    package = pkgs.fprintd.override {
      libfprint = pkgs.callPackage ./libfprint.nix { };
    };
  };
}
