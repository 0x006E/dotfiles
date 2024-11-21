{ pkgs, fetchFromGitHub, ... }:

pkgs.vimUtils.buildVimPlugin {
  name = "tiny-inline-diagnostic";
  version = "0-unstable-2024-11-08";
  src = fetchFromGitHub {
    owner = "rachartier";
    repo = "tiny-inline-diagnostic.nvim";
    rev = "86050f39a62de48734f1a2876d70d179b75deb7c";
    hash = "sha256-A4v8pZuzuH/MSWYF7Hg7ZQo2HNLqlE7dZMhylPEpTdM=";
  };
}
