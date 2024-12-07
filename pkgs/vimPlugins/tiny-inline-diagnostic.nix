{
  lib,
  pkgs,
  fetchFromGitHub,
}:

pkgs.vimUtils.buildVimPlugin rec {
  pname = "tiny-inline-diagnostic-nvim";
  version = "0-unstable-2024-12-06";

  src = fetchFromGitHub {
    owner = "rachartier";
    repo = "tiny-inline-diagnostic.nvim";
    rev = "32c7e2eb8f36792056328e6c239d6365de9f8c7d";
    hash = "sha256-bc1p313YOkj2GI7U35lEomOxB83iJu23iTWyJyI05tU=";
  };

  meta = {
    description = "A Neovim plugin that display prettier diagnostic messages. Display diagnostic messages where the cursor is, with icons and colors";
    homepage = "https://github.com/rachartier/tiny-inline-diagnostic.nvim";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
  };
}
