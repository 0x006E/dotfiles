{ pkgs, fetchFromGitHub, ... }:

pkgs.vimUtils.buildVimPlugin rec {
  name = "magazine.nvim";
  version = "0.4.1";
  src = fetchFromGitHub {
    owner = "iguanacucumber";
    repo = "magazine.nvim";
    rev = "${version}";
    hash = "";
  };
}
