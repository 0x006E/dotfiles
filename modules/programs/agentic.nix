{ delib, inputs, ... }:
delib.module {
  name = "programs.agentic";

  home.always =
    { ... }:
    {
      pkgs,
      ...
    }:
    {
      home.packages =
        with pkgs;
        [
          inputs.antigravity.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-ide

          inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode
          inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode2
        ];

      xdg.desktopEntries.antigravity-ide = {
        name = "Google Antigravity IDE";
        genericName = "Next-generation agentic IDE";
        exec = "antigravity-ide --password-store=gnome %U";
        icon = "antigravity-ide";
        terminal = false;
        categories = [
          "Development"
          "IDE"
        ];
        mimeType = [ "x-scheme-handler/antigravity" ];
        settings = {
          StartupWMClass = "Antigravity IDE";
          StartupNotify = "true";
        };
      };
    };
}
