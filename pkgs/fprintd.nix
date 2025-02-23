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
      hash = "sha256-aGIz50S0zfE3rV6QJp8iQz3uUVn8WAL68KU70j8GyOU=";
    };
    version = "1.94.5";
    mesonCheckFlags = oldAttrs.mesonCheckFlags ++ [
      # PAM related checks are timing out
      "--no-suite"
      "fprintd:TestPamFprintd"
    ];
  })
