{ pkgs, fetchFromGitHub }:
pkgs.vimUtils.buildVimPlugin {
  name = "workspace-diagnostics.nvim";
  src = fetchFromGitHub {
    owner = "artemave";
    repo = "workspace-diagnostics.nvim";
    rev = "573ff93c47898967efdfbc6587a1a39e3c2d365e";
    hash = "sha256-lBj4KUPmmhtpffYky/HpaTwY++d/Q9socp/Ys+4VeX0=";
  };
}
