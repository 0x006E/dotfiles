{ delib, inputs, ... }:
delib.module {
  name = "programs.agentic";

  home.always =
    { myconfig, ... }:
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      home.packages = with pkgs; [
        inputs.antigravity.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-ide
      ];
    };
}
