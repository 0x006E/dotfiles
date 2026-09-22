{ pkgs, fetchFromGitHub }:
pkgs.vimUtils.buildVimPlugin {
  name = "workspace-diagnostics.nvim";
  version = "0-unstable-2026-09-21";
  src = fetchFromGitHub {
    owner = "artemave";
    repo = "workspace-diagnostics.nvim";
    rev = "ea93521c0344fa2530c6f6da8b059d1b944ca550";
    hash = "sha256-xVZYcOw+n/6+4aW+7pcngTTQUBbGsO+QjcHXf3GtaFs=";
  };
}
