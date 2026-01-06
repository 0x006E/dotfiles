{
  lib,
  vimUtils,
  fetchFromGitHub,
}:

vimUtils.buildVimPlugin {
  pname = "signup-nvim";
  version = "0-unstable-2026-01-05";

  src = fetchFromGitHub {
    owner = "Dan7h3x";
    repo = "signup.nvim";
    rev = "1a00bd5a7a0e7722f0ba58cc6de50a93170f8248";
    hash = "sha256-1VO2B/4EvAfKUPWQX4gdtz3Ej09oSKdr4LIHRnPIzYU=";
  };

  meta = {
    description = "A little (smart maybe) lsp signature helper for neovim";
    homepage = "https://github.com/Dan7h3x/signup.nvim";
    license = lib.licenses.gpl3Only;
    maintainers = [ ];
    mainProgram = "signup-nvim";
    platforms = lib.platforms.all;
  };
}
