{
  lib,
  fetchFromGitLab,
  pkgs,
}:
# for the curious, "tod" means "Touch OEM Drivers" meaning it can load
# external .so's.
pkgs.libfprint.overrideAttrs (old: rec {
  pname = "libfprint";

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
    ./patches/001-fprintd-sigfm.patch
  ];
  meta = with lib; {
    homepage = "https://gitlab.freedesktop.org/libfprint/libfprint";
    description = "A library designed to make it easy to add support for consumer fingerprint readers, with support for loaded drivers";
    license = licenses.lgpl21;
    platforms = platforms.linux;
    maintainers = with maintainers; [ ];
  };
})
