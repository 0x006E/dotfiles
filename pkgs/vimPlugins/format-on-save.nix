{
  pkgs,
  fetchFromGitHub,
}:
pkgs.vimUtils.buildVimPlugin {
  name = "format-on-save";
  version = "0-unstable-2025-07-20";
  src = fetchFromGitHub {
    owner = "elentok";
    repo = "format-on-save.nvim";
    rev = "523256bd71543fd68184f67e82dc3cfd5092cf93";
    hash = "sha256-Qubsw5o/mczpL2KpUJIWM9j3acbnC/FT5nqKM0PC75Q=";
  };
}
