{ delib, inputs, ... }:
delib.module {
  name = "core.overlays";

  # Repo overlays apply unconditionally; feature toggles must not silently
  # remove pkgs like boomaga or the custom vim plugins.
  nixos.always = {
    nixpkgs.overlays = import ../../overlays { inherit inputs; };
  };
}
