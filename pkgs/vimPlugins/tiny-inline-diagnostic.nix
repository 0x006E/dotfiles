{ pkgs, fetchFromGitHub, ... }:

pkgs.vimUtils.buildVimPlugin {
  name = "tiny-inline-diagnostic";
  src = fetchFromGitHub {
    owner = "rachartier";
    repo = "tiny-inline-diagnostic.nvim";
    rev = "a4f8b29eb318b507a5e5c11e6d69bea4f5bc2ab2";
    hash = "sha256-S+O5hI0hF3drTwTwIlQ3aPl9lTBErt53lgUFlQGSCA8=";
  };
}
