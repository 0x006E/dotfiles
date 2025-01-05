{
  pkgs,
  fetchFromGitHub,
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
}
