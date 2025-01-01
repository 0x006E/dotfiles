{
  pkgs,
  fetchFromGitHub,
  fetchpatch,
}:
pkgs.vimUtils.buildVimPlugin {
  name = "format-on-save";
  version = "0-unstable-2024-12-25";
  src = fetchFromGitHub {
    owner = "elentok";
    repo = "format-on-save.nvim";
    rev = "a224e5f6fa42cc02ce002938aff39ff43455f28f";
    hash = "sha256-7uJpTg2VBuas89SI1viuCKZhqgSl+iCriC3ZVuDCrBc=";
  };
  patches = [
    (fetchpatch {
      url = "https://github.com/elentok/format-on-save.nvim/pull/24.patch";
      hash = "sha256-g1SSjxCaoP/AAUBkOY1ZSVI9wuDl5o5Sie8YzZt6zgQ=";
    })

  ];
}
