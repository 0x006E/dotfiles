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
    # Global opencode config: available in every repo session, merged by
    # opencode with project-local opencode.json files. Tracker MCP lives
    # here (not per-project) because wayfinder runs across repos.
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

        "opencode/opencode.json".text = builtins.toJSON {
          "$schema" = "https://opencode.ai/config.json";
          mcp = {
            # Up-to-date library docs: agents look up APIs instead of
            # guessing from stale training data.
            context7 = {
              type = "local";
              command = [
                "npx"
                "-y"
                "@upstash/context7-mcp"
              ];
            };
            # Notion tracker: official hosted MCP over Streamable HTTP.
            # Auth is OAuth, completed interactively in opencode on first
            # use — no tokens in config, no local services.
            notion = {
              type = "remote";
              url = "https://mcp.notion.com/mcp";
              enabled = true;
            };
            # Cross-session memory: agents persist decisions, prefs, and
            # context pointers here instead of re-deriving them each session.
            memory = {
              type = "local";
              command = [
                "npx"
                "-y"
                "@modelcontextprotocol/server-memory"
              ];
              enabled = true;
            };
            # Structured step-by-step reasoning: better grilling, planning,
            # and wayfinder ticket resolution.
            sequential-thinking = {
              type = "local";
              command = [
                "npx"
                "-y"
                "@modelcontextprotocol/server-sequential-thinking"
              ];
              enabled = true;
            };
            # Web fetching for agents: primary-source reads for research
            # tickets without leaving the session.
            fetch = {
              type = "local";
              command = [
                "npx"
                "-y"
                "@modelcontextprotocol/server-fetch"
              ];
              enabled = true;
            };
          };
        };
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
