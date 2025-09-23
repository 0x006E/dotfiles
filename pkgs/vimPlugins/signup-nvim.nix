{
  lib,
  vimUtils,
  fetchFromGitHub,
}:

vimUtils.buildVimPlugin {
  pname = "signup-nvim";
  version = "0-unstable-2025-09-15";

  src = fetchFromGitHub {
    owner = "Dan7h3x";
    repo = "signup.nvim";
    rev = "86d8c2959b947f29de62da4dc48564aff36441e8";
    hash = "sha256-xOYg5NHf8rRU3P1OErVNXxo40tRi7gLSjW0nHNKeNTs=";
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
