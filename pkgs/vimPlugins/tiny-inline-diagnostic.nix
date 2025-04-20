{
  lib,
  pkgs,
  fetchFromGitHub,
}:

pkgs.vimUtils.buildVimPlugin rec {
  pname = "tiny-inline-diagnostic-nvim";
  version = "0-unstable-2025-04-18";

  src = fetchFromGitHub {
    owner = "rachartier";
    repo = "tiny-inline-diagnostic.nvim";
    rev = "cd401038de4cbae37651cfe02510294ccf5cdc98";
    hash = "sha256-9o+vHZVpY46j2xPOgjgT2JUfJ+FAzJGJaj6LXQ77QtU=";
  };

  meta = {
    description = "A Neovim plugin that display prettier diagnostic messages. Display diagnostic messages where the cursor is, with icons and colors";
    homepage = "https://github.com/rachartier/tiny-inline-diagnostic.nvim";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
  };
}
