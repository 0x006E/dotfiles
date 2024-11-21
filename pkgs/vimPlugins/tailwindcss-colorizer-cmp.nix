{ pkgs, fetchFromGitHub, ... }:

pkgs.vimUtils.buildVimPlugin {
  name = "tailwindcss-colorizer-cmp";
  src = fetchFromGitHub {
    owner = "roobert";
    repo = "tailwindcss-colorizer-cmp.nvim";
    rev = "3d3cd95e4a4135c250faf83dd5ed61b8e5502b86";
    hash = "sha256-PIkfJzLt001TojAnE/rdRhgVEwSvCvUJm/vNPLSWjpY=";
  };
}
