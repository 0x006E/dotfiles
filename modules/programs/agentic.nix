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
        inputs.antigravity.packages.${pkgs.system}.google-antigravity-ide
      ];
    };
}
