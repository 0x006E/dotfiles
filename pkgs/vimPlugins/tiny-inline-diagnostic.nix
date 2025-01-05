{
  lib,
  pkgs,
  fetchFromGitHub,
}:

pkgs.vimUtils.buildVimPlugin rec {
  pname = "tiny-inline-diagnostic-nvim";
  version = "0-unstable-2024-12-30";

  src = fetchFromGitHub {
    owner = "rachartier";
    repo = "tiny-inline-diagnostic.nvim";
    rev = "867902d5974a18c156c918ab8addbf091719de27";
    hash = "sha256-rZ5+w6v9ONFTQIXvwTUJuwZKRaXdHZUNEUDfBsC2IMM=";
  };

  meta = {
    description = "A Neovim plugin that display prettier diagnostic messages. Display diagnostic messages where the cursor is, with icons and colors";
    homepage = "https://github.com/rachartier/tiny-inline-diagnostic.nvim";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
  };
}
