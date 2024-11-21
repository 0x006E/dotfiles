{ pkgs, fetchFromGitHub, ... }:

pkgs.vimUtils.buildVimPlugin rec {
  name = "magazine.nvim";
  version = "0.4.1";
  src = fetchFromGitHub {
    owner = "iguanacucumber";
    repo = "magazine.nvim";
    rev = "${version}";
    hash = "sha256-qZsyQ6C8ODtJLT2XW5Mt2uD/WVrPSJzvGhnDeaAiqPA=";
  };
}
