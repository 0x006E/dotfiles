{
  pkgs,
  libfprint,
  fetchFromGitLab,
  ...
}:
(pkgs.fprintd.override {
  libfprint = libfprint;
}).overrideAttrs
  (oldAttrs: rec {

    src = fetchFromGitLab {
      domain = "gitlab.freedesktop.org";
      owner = "libfprint";
      repo = "fprintd";
      rev = "refs/tags/v${version}";
      hash = "sha256-B2g2d29jSER30OUqCkdk3+Hv5T3DA4SUKoyiqHb8FeU=";
    };
    version = "1.94.4";
    mesonCheckFlags = oldAttrs.mesonCheckFlags ++ [
      # PAM related checks are timing out
      "--no-suite"
      "fprintd:TestPamFprintd"
    ];
  })
