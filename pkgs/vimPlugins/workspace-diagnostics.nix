{ pkgs, fetchFromGitHub }:
pkgs.vimUtils.buildVimPlugin {
  name = "workspace-diagnostics.nvim";
  version = "0-unstable-2025-05-25";
  src = fetchFromGitHub {
    owner = "artemave";
    repo = "workspace-diagnostics.nvim";
    rev = "60f9175b2501ae3f8b1aba9719c0df8827610c8e";
    hash = "sha256-jSpKaKnGyip/nzqU52ypWLgoCtvccYN+qb5jzlwAnd4=";
  };
}
