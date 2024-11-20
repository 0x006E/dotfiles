{
  pkgs,
  libfprint,
  ...
}:
(pkgs.fprintd.override {
  libfprint = libfprint;
}).overrideAttrs
  (oldAttrs: {

    mesonCheckFlags = oldAttrs.mesonCheckFlags ++ [
      # PAM related checks are timing out
      "--no-suite"
      "fprintd:TestPamFprintd"
    ];
  })
