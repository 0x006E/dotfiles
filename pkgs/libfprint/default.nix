{
  pkgs,
  fetchFromGitLab,
}:
pkgs.libfprint.overrideAttrs (old: {
  version = "1.94.5";
  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "0x00002a";
    repo = "libfprint";
    rev = "bfb77a332632822196af95ea3763872d293ccd7a";
    hash = "sha256-gfIqbqahYXTcLtCUQ5GV8MKWuDWPDzSV60GHQN41J7o=";
  };
  buildInputs = old.buildInputs ++ [
    pkgs.opencv
  ];
  patches = [
    ./001-fprintd-sigfm.patch
  ];
})
