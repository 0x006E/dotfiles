{
  lib,
  vimUtils,
  fetchFromGitHub,
}:

vimUtils.buildVimPlugin {
  pname = "signup-nvim";
  version = "0-unstable-2024-11-27";

  src = fetchFromGitHub {
    owner = "Dan7h3x";
    repo = "signup.nvim";
    rev = "2b21a2aa51efbdeb9454a3f5d62659368d87d420";
    hash = "sha256-EKsvX+vSQLszioosknDReukmlz4yJsxy+3gAJOrvSZA=";
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
