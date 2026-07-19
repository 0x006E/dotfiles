{ delib, inputs, ... }:
delib.module {
  name = "programs.ide";

  home.always =
    { myconfig, ... }:
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      imports = [
        inputs.nixvim.homeModules.nixvim
        ../../nixvim-config
      ];

      programs = {
        vscode = {
          enable = true;
          mutableExtensionsDir = false;
          profiles.default.extensions = with pkgs.vscode-marketplace; [
            saoudrizwan.claude-dev
            pkgs.vscode-extensions.vadimcn.vscode-lldb
            ms-vscode.mono-debug
            ms-python.debugpy
            golang.go
            sumneko.lua
            rust-lang.rust-analyzer
            ziglang.vscode-zig
            tamasfe.even-better-toml
            serayuzgur.crates
            bbenoist.nix
            brettm12345.nixfmt-vscode
            ms-python.python
            esbenp.prettier-vscode
            bradlc.vscode-tailwindcss
            ms-vscode.live-server
            dbaeumer.vscode-eslint
            yzhang.markdown-all-in-one
            marp-team.marp-vscode
            dart-code.flutter
            nash.awesome-flutter-snippets
            dart-code.dart-code
            marufhassan.flutter
            github.codespaces
            ms-vscode-remote.remote-containers
            pkgs.vscode-extensions.ms-dotnettools.vscode-dotnet-runtime
            github.copilot
            mkhl.direnv
            redhat.java
            vscjava.vscode-java-debug
            vscjava.vscode-java-test
            vscjava.vscode-maven
            vscjava.vscode-gradle
            vscjava.vscode-java-dependency
            vmware.vscode-spring-boot
            vscjava.vscode-spring-initializr
            vscjava.vscode-spring-boot-dashboard
          ];
        };
      };

      home.packages = with pkgs; [ pre-commit ];
    };
}
