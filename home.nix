{
  inputs,
  pkgs,
  pkgs-stable,
  ...
}:
{
  imports = [
    inputs.walker.homeManagerModules.default
    inputs.nix-index-database.hmModules.nix-index
    inputs.nixvim.homeManagerModules.nixvim
    ./niri.nix
    ./waybar.nix
    ./ide.nix
  ];

  home = {
    username = "nithin";
    homeDirectory = "/home/nithin";
    stateVersion = "24.05";

    packages = with pkgs; [
      # Office and Graphics
      libreoffice
      gimp

      # Development Tools
      vimgolf
      devpod
      # zen-browser
      pre-commit
      cabal-install
      ghc
      nixfmt-rfc-style
      hoppscotch

      # System Tools
      foot
      blueman
      pinentry-qt
      distrobox
      xorg.xhost
      udiskie
      fuzzel

      # Security and Privacy
      keybase-gui
      kbfs
      pkgs-stable.bitwarden

      # Media and Entertainment
      mpv
      ff2mpv-rust
      stirling-pdf
      stremio
      vesktop
      obs-studio

      # Cloud and Sync
      onedriver

      # Custom Packages
      (pkgs.callPackage ./responsively-app.nix { })
      (pkgs.callPackage ./zoho-mail.nix { })

      # Gaming
      (lutris.override {
        extraLibraries = pkgs: [
          mangohud
          wineWowPackages.waylandFull
          bash
          winetricks
        ];
      })
    ];

    sessionVariables = { };
  };

  programs = {
    home-manager.enable = true;

    firefox = {
      enable = true;
      package = pkgs.wrapFirefox pkgs.zen-browser-unwrapped {
        pname = "zen-browser";
        libName = "zen";
      };
      policies = {
        ExtensionSettings =
          with builtins;
          let
            extension = shortId: uuid: {
              name = uuid;
              value = {
                install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
                installation_mode = "normal_installed";
              };
            };
          in
          listToAttrs [
            (extension "ublock-origin" "uBlock0@raymondhill.net")
            (extension "bitwarden-password-manager" "{446900e4-71c2-419f-a6a7-df9c091e268b}")
            (extension "libredirect" "7esoorv3@alefvanoon.anonaddy.me")
            (extension "2fas-two-factor-authentication" "admin@2fas.com")
            (extension "sponsorblock" "sponsorBlocker@ajay.app")
            (extension "dearrow" "deArrow@ajay.app")
            (extension "enhancer-for-youtube" "enhancerforyoutube@maximerf.addons.mozilla.org")
            (extension "tabliss" "extension@tabliss.io")
            (extension "don-t-fuck-with-paste" "DontFuckWithPaste@raim.ist")
            (extension "clearurls" "{74145f27-f039-47ce-a470-a662b129930a}")
            (extension "react-devtools" "@react-devtools")
          ];
        # To add additional extensions, find it on addons.mozilla.org, find
        # the short ID in the url (like https://addons.mozilla.org/en-US/firefox/addon/!SHORT_ID!/)
        # Then, download the XPI by filling it in to the install_url template, unzip it,
        # run `jq .browser_specific_settings.gecko.id manifest.json` or
        # `jq .applications.gecko.id manifest.json` to get the UUID
      };
    };
    walker = {
      enable = true;
      runAsService = true;
    };

    nix-index = {
      enable = true;
      enableBashIntegration = true;
    };
    nix-index-database.comma.enable = true;

    vscode = {
      enable = true;
      mutableExtensionsDir = false;
      extensions = with pkgs.vscode-marketplace; [
        # Debug Tools
        vadimcn.vscode-lldb
        ms-dotnettools.csdevkit
        ms-vscode.mono-debug
        ms-python.debugpy

        # Language Support
        rust-lang.rust-analyzer
        tamasfe.even-better-toml
        serayuzgur.crates
        bbenoist.nix
        brettm12345.nixfmt-vscode
        ms-python.python
        ms-dotnettools.csharp

        # Web Development
        esbenp.prettier-vscode
        bradlc.vscode-tailwindcss
        ms-vscode.live-server
        dbaeumer.vscode-eslint

        # Documentation
        yzhang.markdown-all-in-one
        marp-team.marp-vscode

        # Flutter/Dart
        dart-code.flutter
        nash.awesome-flutter-snippets
        dart-code.dart-code
        marufhassan.flutter

        # Remote Development
        github.codespaces
        ms-vscode-remote.remote-containers
        ms-dotnettools.vscode-dotnet-runtime

        # AI/Copilot
        github.copilot

        # Tools
        mkhl.direnv
      ];
    };

    git = {
      enable = true;
      userName = "Nithin S Varrier";
      userEmail = "me@ntsv.dev";
      signing = {
        signByDefault = true;
        key = null;
      };
    };

    starship = {
      enable = true;
      settings = {
        add_newline = false;
        aws.disabled = true;
        gcloud.disabled = true;
        line_break.disabled = true;
      };
    };

    direnv = {
      enable = true;
      package = pkgs.direnv.overrideAttrs (oldAttrs: {
        patches = oldAttrs.patches or [ ] ++ [
          (pkgs.fetchpatch {
            url = "https://github.com/direnv/direnv/pull/1048.patch";
            hash = "sha256-BG+ekOPVBWsosMLxTCJPOQWX1eOrWiIfDswd1Xk/4GU=";
          })
        ];
      });
      nix-direnv.enable = true;
      enableBashIntegration = true;
    };

    bash = {
      enable = true;
      enableCompletion = true;
      bashrcExtra = ''
        eval "$(direnv hook bash)"
        export DISPLAY=:0
        export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin"
      '';
      shellAliases = {
        mc = "pushd ~/nix;nvim ~/nix;popd";
        rs = "nh os switch ~/nix ";
        rb = "nh os boot ~/nix ";
        k = "kubectl";
        urldecode = "python3 -c 'import sys, urllib.parse as ul; print(ul.unquote_plus(sys.stdin.read()))'";
        urlencode = "python3 -c 'import sys, urllib.parse as ul; print(ul.quote_plus(sys.stdin.read()))'";
      };
    };
  };

  services = {
    swaync.enable = true;

    conky = {
      enable = true;
      extraConfig = ''
        out_to_x = false,
        out_to_wayland = true,
      '';
    };

    udiskie.enable = true;

    flameshot = {
      enable = true;
      package = pkgs.flameshot.override { enableWlrSupport = true; };
      settings.General = {
        disabledTrayIcon = true;
        showStartupLaunchMessage = false;
      };
    };

    keybase.enable = true;
  };

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };
  };
}
