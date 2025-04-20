{
  lib,
  vimUtils,
  fetchFromGitHub,
}:

vimUtils.buildVimPlugin {
  pname = "signup-nvim";
  version = "0-unstable-2025-04-13";

  src = fetchFromGitHub {
    owner = "Dan7h3x";
    repo = "signup.nvim";
    rev = "944c4519ba851579d40556b708e272746e298744";
    hash = "sha256-8A+gm8WU71Ekfu0l7qjTC/weMWmbC7RebnOHBhuZkbQ=";
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
