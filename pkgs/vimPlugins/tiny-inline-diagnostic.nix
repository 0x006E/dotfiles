{
  lib,
  pkgs,
  fetchFromGitHub,
}:

pkgs.vimUtils.buildVimPlugin rec {
  pname = "tiny-inline-diagnostic-nvim";
  version = "0-unstable-2025-03-11";

  src = fetchFromGitHub {
    owner = "rachartier";
    repo = "tiny-inline-diagnostic.nvim";
    rev = "5d168a2826fb90691f674e81bd5c1dfa6d931c61";
    hash = "sha256-WWT/RGP4+OB6CvEKvGed+aD0Yf30AQvnOcOKZ/gjggk=";
  };

  meta = {
    description = "A Neovim plugin that display prettier diagnostic messages. Display diagnostic messages where the cursor is, with icons and colors";
    homepage = "https://github.com/rachartier/tiny-inline-diagnostic.nvim";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
  };
}
