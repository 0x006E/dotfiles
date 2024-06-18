{
  config,
  pkgs,
  ...
}: {
  nixpkgs.config = {
    packageOverrides = super: let
      self = super.pkgs;
    in {
      iosevka-term = self.iosevka.override {
        set = "term";
        design = [
          "term"
          "v-l-italic"
          "v-i-italic"
          "v-g-singlestorey"
          "v-zero-dotted"
          "v-asterisk-high"
          "v-at-long"
          "v-brace-straight"
        ];
      };
    };
  };
  fonts = {
    fontconfig = {
      # ultimate.enable = true; # This enables fontconfig-ultimate settings for better font rendering
      defaultFonts = {monospace = ["Iosevka"];};
    };
    fontDir.enable = true;
    enableGhostscriptFonts = true;
    packages = with pkgs; [terminus_font corefonts noto-fonts iosevka-term];
  };
}
