{
  config,
  pkgs,
  ...
}: {
  services.fprintd.enable = true;
  services.fprintd.tod.enable = true;
  services.fprintd.tod.driver = pkgs.libfprint-tod;

  environment.systemPackages = with pkgs; [
    fprintd
  ];
}
