{
  lib,
  vimUtils,
  fetchFromGitHub,
}:

vimUtils.buildVimPlugin {
  pname = "signup-nvim";
  version = "0-unstable-2025-06-25";

  src = fetchFromGitHub {
    owner = "Dan7h3x";
    repo = "signup.nvim";
    rev = "22f5c606b90161e4e78b62f401e8618eb18d9f3f";
    hash = "sha256-y7nMDMDb40Pj65Ejq9tKwNe1ygnbRUtRAJYaRSmhLtU=";
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
