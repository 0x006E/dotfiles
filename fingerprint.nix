{
  pkgs,
  ...
}:
{
  services.fprintd = {
    enable = false;
    package = pkgs.fprintd;
  };
}
