{
  inputs,
  pkgs,
  pkgs-stable,
  config,
  ...
}:
let
  username = "ntsv";
in
{
  imports = [
    inputs.nixvim.homeModules.nixvim
    inputs.zen-browser.homeModules.beta
    inputs.noctalia.homeModules.default
    ./niri.nix
    # ./waybar.nix
    ./ide
    ./wayprompt
    ./gpg
    # ./rofi.nix
    ./kanshi.nix
    ./noctalia.nix
  ];

  home = {
    username = "nithin";
    homeDirectory = "/home/nithin";
    stateVersion = "24.05";

    packages = with pkgs; [
      filen-cli
      filen-desktop
      # Office and Graphics
      libreoffice
      gimp

      # Development Tools
      pre-commit

      # System Tools
      foot
      overskride

      udiskie

      # Media and Entertainment
      mpv
      stirling-pdf

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

  };

  gtk = {
    enable = true;
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.catppuccin-papirus-folders.override {
        flavor = "mocha";
        accent = "lavender";
      };
    };
    cursorTheme = {
      name = "Catppuccin-Mocha-Light-Cursors";
      package = pkgs.catppuccin-cursors.mochaLight;
    };
    gtk3 = {
      extraConfig.gtk-application-prefer-dark-theme = true;
    };
  };
  programs = {
    rclone.enable = true;
    home-manager.enable = true;
    atuin = {
      enable = true;
      enableBashIntegration = true;
      settings = {
        style = "compact";
        inline_height = 40;
        enter_accept = false;
      };
    };
    zen-browser = {
      enable = true;
      profiles = {
        ${username} = {
          id = 0;
          name = "${username}";
          # profileAvatarPath = "chrome://browser/content/zen-avatars/avatar-57.svg";
          path = "${username}.default";
          isDefault = true;
          settings = {
            # "af.edgyarc.centered-url" = true;
            # "af.edgyarc.minimal-navbar" = true;
            # "af.edgyarc.thin-navbar" = true;
            "signon.rememberSignons" = false;
            "af.sidebery.edgyarc-theme" = true;
            "browser.cache.jsbc_compression_level" = 3;
            "dom.enable_web_task_scheduling" = true;
            "gfx.canvas.accelerated" = true;
            "gfx.canvas.accelerated.cache-item" = 4096;
            "gfx.canvas.accelerated.cache-size" = 512;
            "gfx.content.skia-font-cache-size" = 20;
            "image.mem.decode_bytes_at_a_time" = 32768;
            "layout.css.color-mix.enabled" = true;
            "layout.css.grid-template-masonry-value.enabled" = true;
            "layout.css.has-selector.enabled" = true;
            "layout.css.light-dark.enabled" = true;
            "media.cache_readahead_limit" = 7200;
            "media.cache_resume_threshold" = 3600;
            "media.memory_cache_max_size" = 65536;
            "network.dnsCacheExpiration" = 3600;
            "network.dns.disablePrefetch" = true;
            "network.dns.disablePrefetchFromHTTPS" = true;
            "network.http.max-connections" = 1800;
            "network.http.max-persistent-connections-per-server" = 10;
            "network.http.max-urgent-start-excessive-connections-per-host" = 5;
            "network.http.pacing.requests.enabled" = false;
            "network.predictor.enabled" = false;
            "network.prefetch-next" = false;
            "network.ssl_tokens_cache_capacity" = 10240;
            "svg.context-properties.content.enabled" = true;
            "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
            "uc.tweak.af.greyscale-webext-icons" = true;
            "uc.tweak.floating-tabs" = true;
            "uc.tweak.hide-forward-button" = true;
            "uc.tweak.hide-tabs-bar" = true;
            "uc.tweak.rounded-corners" = true;
            "widget.macos.titlebar-blend-mode.behind-window" = true;
          };
        };
      };
      policies = {
        PasswordManagerEnabled = false;
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
        # the short ID in the url (like https=//addons.mozilla.org/en-US/firefox/addon/!SHORT_ID!/)
        # Then, download the XPI by filling it in to the install_url template, unzip it,
        # run `jq .browser_specific_settings.gecko.id manifest.json` or
        # `jq .applications.gecko.id manifest.json` to get the UUID
      };
    };

    vscode = {
      enable = true;
      mutableExtensionsDir = false;
      profiles.default.extensions = with pkgs.vscode-marketplace; [
        # Debug Tools
        pkgs.vscode-extensions.vadimcn.vscode-lldb
        ms-vscode.mono-debug
        ms-python.debugpy
        golang.go
        sumneko.lua

        # Language Support
        rust-lang.rust-analyzer
        tamasfe.even-better-toml
        serayuzgur.crates
        bbenoist.nix
        brettm12345.nixfmt-vscode
        ms-python.python

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
        pkgs.vscode-extensions.ms-dotnettools.vscode-dotnet-runtime

        # AI/Copilot
        github.copilot

        # Tools
        mkhl.direnv

        # Java

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

    git = {
      enable = true;
      userName = "Nithin S Varrier";
      userEmail = "me@ntsv.dev";
      signing = {
        signByDefault = true;
        key = null;
      };
      extraConfig = {
        commit.gpgsign = true;
        tag.gpgSign = true;
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
        export DISPLAY=:12
        export PATH="$PATH:$HOME/bin=$HOME/.local/bin:$HOME/go/bin"
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
    udiskie.enable = true;

    kdeconnect = {
      enable = true;
      indicator = true;
    };
    flameshot = {
      enable = true;
      package = pkgs.flameshot.override { enableWlrSupport = true; };
      settings.General = {
        disabledTrayIcon = true;
        showStartupLaunchMessage = false;
      };
    };

  };

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };
  };
}
