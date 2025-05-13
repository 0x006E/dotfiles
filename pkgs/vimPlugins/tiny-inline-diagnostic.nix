{
  lib,
  pkgs,
  fetchFromGitHub,
}:

pkgs.vimUtils.buildVimPlugin rec {
  pname = "tiny-inline-diagnostic-nvim";
  version = "0-unstable-2025-05-12";

  src = fetchFromGitHub {
    owner = "rachartier";
    repo = "tiny-inline-diagnostic.nvim";
    rev = "b6ed8038dfd256eb963a2c79cb30f0f4683551a0";
    hash = "sha256-CfrziWYhSWoChfHtDgcSff76v7INYrNNIIlpHE/aR1k=";
  };

  meta = {
    description = "A Neovim plugin that display prettier diagnostic messages. Display diagnostic messages where the cursor is, with icons and colors";
    homepage = "https://github.com/rachartier/tiny-inline-diagnostic.nvim";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
  };
}
