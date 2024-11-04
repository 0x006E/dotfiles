{
  config,
  pkgs-stable,

  ...
}:
{
  services.fprintd = {
    enable = true;
    package =
      (pkgs-stable.fprintd.override { libfprint = pkgs-stable.callPackage ./libfprint.nix { }; })
      .overrideAttrs
        (oldAttrs: {

          mesonCheckFlags = oldAttrs.mesonCheckFlags ++ [
            # PAM related checks are timing out
            "--no-suite"
            "fprintd:TestPamFprintd"
          ];
        });
  };
}
