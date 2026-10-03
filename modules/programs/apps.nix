{
  delib,
  pkgs,
  pkgs-stable,
  ...
}:
delib.module {
  name = "programs.apps";
  options = delib.singleEnableOption true;

  home.ifEnabled = { ... }: {
    home.packages = with pkgs; [
      librum
      # TODO: re-enable once winboat drops electron_40 (EOL/insecure in nixpkgs, nixpkgs#537847)
      # winboat
      # filen-desktop dropped, not blocked: its bundled node-canvas 3.1.0 does
      # not build against gcc 16 (transitive <cstdint> includes removed), which
      # breaks the toplevel build on any nixpkgs bump. Upstream, unfixed:
      # NixOS/nixpkgs#569059. The CLI (filen-cli) is a separate derivation and
      # is fine.
      filen-cli
      libreoffice
      gimp
      foot
      overskride
      mpv
      nuvio
      pkgs-stable.bottles
      winetricks
    ];
  };
}
