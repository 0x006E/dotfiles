{
  delib,
  inputs,
  pkgs,
  ...
}:
delib.module {
  name = "programs.agentic";
  options = delib.singleEnableOption true;

  home.ifEnabled = { ... }: {
    home.packages = with pkgs; [
      codegraph

      inputs.antigravity.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-ide

      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode2
    ];

    # Wayfinder skill + its runtime deps (grilling, domain-modeling,
    # prototype, research, setup). Pinned via the mattpocock-skills flake
    # input; symlinked whole directories so SKILL.md + siblings (agents/,
    # reference .md files) stay intact for opencode discovery at
    # ~/.config/opencode/skills/<name>/SKILL.md.
    xdg.configFile =
      let
        skills = inputs.mattpocock-skills;
      in
      {
        "opencode/skills/wayfinder".source = "${skills}/skills/engineering/wayfinder";
        "opencode/skills/grilling".source = "${skills}/skills/productivity/grilling";
        "opencode/skills/domain-modeling".source = "${skills}/skills/engineering/domain-modeling";
        "opencode/skills/prototype".source = "${skills}/skills/engineering/prototype";
        "opencode/skills/research".source = "${skills}/skills/engineering/research";
        "opencode/skills/setup-matt-pocock-skills".source =
          "${skills}/skills/engineering/setup-matt-pocock-skills";
      };

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
