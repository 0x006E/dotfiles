{ pkgs, fetchFromGitHub }:
pkgs.vimUtils.buildVimPlugin {
  name = "workspace-diagnostics.nvim";
  version = "0-unstable-2026-05-04";
  src = fetchFromGitHub {
    owner = "artemave";
    repo = "workspace-diagnostics.nvim";
    rev = "a35321d8401878cc9558e357acfd0da58b582739";
    hash = "sha256-xVZYcOw+n/6+4aW+7pcngTTQUBbGsO+QjcHXf3GtaFs=";
  };
}
