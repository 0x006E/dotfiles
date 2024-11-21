{
  pkgs,
  fetchFromGitHub,
  fetchpatch,
}:
pkgs.vimUtils.buildVimPlugin {
  name = "format-on-save";
  version = "0-unstable-2024-05-20";
  src = fetchFromGitHub {
    owner = "elentok";
    repo = "format-on-save.nvim";
    rev = "fed870bb08d9889580f5ca335649da2074bd4b6f";
    hash = "sha256-07RWMrBDVIH3iGgo2RcNDhThSrR/Icijcd//MOnBzpA=";
  };
  patches = [
    (fetchpatch {
      url = "https://github.com/elentok/format-on-save.nvim/pull/24.patch";
      hash = "sha256-g1SSjxCaoP/AAUBkOY1ZSVI9wuDl5o5Sie8YzZt6zgQ=";
    })

  ];
}
