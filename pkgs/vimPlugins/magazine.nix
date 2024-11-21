{ pkgs, fetchFromGitHub, ... }:

pkgs.vimPlugins.nvim-cmp.overrideAttrs (old: {
  src = fetchFromGitHub {
    owner = "iguanacucumber";
    repo = "magazine.nvim";
    rev = "4aec249cdcef9b269e962bf73ef976181ee7fdd9";
    hash = "sha256-qobf9Oyt9Voa2YUeZT8Db7O8ztbGddQyPh5wIMpK/w8=";
  };
})
