{ pkgs, fetchFromGitHub, ... }:
pkgs.vimUtils.buildVimPlugin {
  name = "remote-nvim.nvim";
  src = fetchFromGitHub {
    owner = "amitds1997";
    repo = "remote-nvim.nvim";
    rev = "ffbf91f6132289a8c43162aba12c7365c28d601c";
    hash = "sha256-8gKQ7DwubWKfoXY4HDvPeggV+kxhlpz3yBmG9+SZ8AI=";
  };
}
