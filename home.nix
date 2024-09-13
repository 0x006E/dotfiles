{
  inputs,
  pkgs,
  ...
}: {
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "nithin";
  home.homeDirectory = "/home/nithin";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.

  imports = [
    inputs.ags.homeManagerModules.default
    inputs.walker.homeManagerModules.default
    inputs.nix-index-database.hmModules.nix-index
    ./niri.nix
    ./waybar.nix
  ];
  programs.ags = {
    # enable = true;

    # null or path, leave as null if you don't want hm to manage the config
    configDir = ./ags;

    # additional packages to add to gjs's runtime
    extraPackages = with pkgs; [
      gtksourceview
      webkitgtk
      accountsservice
    ];
  };

  programs.walker = {
    enable = true;
    runAsService = true;
    # style = {};
  };

  home.stateVersion = "24.05"; # Please read the comment before changing.

  home.pointerCursor = {
    gtk.enable = true;
    # x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 16;
  };

  gtk = {
    enable = true;
    theme = {
      package = pkgs.flat-remix-gtk;
      name = "Flat-Remix-GTK-Grey-Darkest";
    };

    iconTheme = {
      package = pkgs.gnome.adwaita-icon-theme;
      name = "Adwaita";
    };

    font = {
      name = "Sans";
      size = 11;
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
  };

  xdg.configFile = {
    "Kvantum/ArcDark".source = "${pkgs.arc-kde-theme}/share/Kvantum/ArcDark";
    "Kvantum/kvantum.kvconfig".text = "[General]\ntheme=ArcDark";
  };

  # The home.packages option allows you to install Nix packages into your
  # environment.
  programs.nix-index = {
    enable = true;
    enableBashIntegration = true;
  };
  programs.nix-index-database.comma.enable = true;
  programs.firefox.nativeMessagingHosts.packages = with pkgs; [
    gnomeExtensions.gsconnect
    ff2mpv-rust
  ];
  services.gpg-agent = {
    enable = true;
    enableBashIntegration = true;
    enableSshSupport = true;
    pinentryPackage = pkgs.pinentry-qt;
  };
  programs.gpg.enable = true;

  services.swaync.enable = true;
  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-marketplace; [
      vadimcn.vscode-lldb
      esbenp.prettier-vscode
      bradlc.vscode-tailwindcss
      github.codespaces
      # Languages
      rust-lang.rust-analyzer
      tamasfe.even-better-toml
      serayuzgur.crates

      bbenoist.nix
      brettm12345.nixfmt-vscode

      yzhang.markdown-all-in-one
      marp-team.marp-vscode

      github.copilot

      # Misc
      mkhl.direnv
      ms-vscode.live-server

      # Flutter 
      dart-code.flutter
      nash.awesome-flutter-snippets
      dart-code.dart-code
      marufhassan.flutter
    ];
    mutableExtensionsDir = false;
  };

  services.udiskie.enable = true;
  services.flameshot = {
    enable = true;
    package = pkgs.flameshot.override {enableWlrSupport = true;};
    settings = {
      General = {
        disabledTrayIcon = true;
        showStartupLaunchMessage = false;
      };
    };
  };

  home.packages = with pkgs; [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello
    foot
    keybase-gui
    kbfs
    bitwarden
    pinentry-qt
    distrobox
    xorg.xhost
    neovim
    swww
    nixfmt-rfc-style
    (lutris.override {
      extraLibraries = pkgs: [
        # List library dependencies here
        mangohud
        # (wineWowPackages.unstableFull.override { waylandSupport = true; })
        wineWowPackages.waylandFull
        bash
        winetricks
      ];
    })
    onedriver
    mpv
    ff2mpv-rust
    firefox
    hoppscotch
    stirling-pdf
    stremio
    vesktop
    (pkgs.callPackage ./responsively-app.nix {})
    (pkgs.callPackage ./zoho-mail.nix {})
    fuzzel
    obs-studio
    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };
  programs.git = {
    enable = true;
    userName = "Nithin S Varrier";
    userEmail = "me@ntsv.dev";
    signing = {
      signByDefault = true;
      key = null;
    };
  };
  services.keybase.enable = true;
  # starship - an customizable prompt for any shell
  programs.starship = {
    enable = true;
    # custom settings
    settings = {
      add_newline = false;
      aws.disabled = true;
      gcloud.disabled = true;
      line_break.disabled = true;
    };
  };

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = ["qemu:///system"];
      uris = ["qemu:///system"];
    };
  };

  programs.direnv.enable = true;

  programs.bash = {
    enable = true;
    enableCompletion = true;
    # TODO add your custom bashrc here
    bashrcExtra = ''
      eval "$(direnv hook bash)"
      export DISPLAY=:0
      export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin"
    '';

    # set some aliases, feel free to add more or remove some
    shellAliases = {
      k = "kubectl";
      urldecode = "python3 -c 'import sys, urllib.parse as ul; print(ul.unquote_plus(sys.stdin.read()))'";
      urlencode = "python3 -c 'import sys, urllib.parse as ul; print(ul.quote_plus(sys.stdin.read()))'";
    };
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. If you don't want to manage your shell through Home
  # Manager then you have to manually source 'hm-session-vars.sh' located at
  # either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/nithin/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    # EDITOR = "nvim";
    # WLR_NO_HARDWARE_CURSORS = "1";
    # NIXOS_OZONE_WL = "1";
    # # DISPLAY = ":0";
    # QT_QPA_PLATFORM = "wayland";
  };
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
