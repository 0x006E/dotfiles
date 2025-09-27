{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:
let
  uvcvideo-kernel-module = config.boot.kernelPackages.callPackage ./uvcvideo-kernel-module.nix { };
  acer-wmi-battery-kernel-module = config.boot.kernelPackages.callPackage ./acer-wmi-battery.nix { };
in
{
  imports = [
    ./hardware-configuration.nix
    ./nvidia.nix
    ./font.nix
    ./plymouth.nix
    ./virtualization.nix
    ./printing.nix
    ./stylix.nix
  ];

  nix = {
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    extraOptions = ''
      experimental-features = nix-command flakes parallel-eval
    '';
    settings = {
      auto-optimise-store = true;
      trusted-users = [
        "root"
        "@wheel"
      ];
      substituters = [
        "https://lanzaboote.cachix.org"
        "https://cache.garnix.io"
        "https://0x006e-nix.cachix.org"
      ];
      trusted-public-keys = [
        "lanzaboote.cachix.org-1:Nt9//zGmqkg1k5iu+B3bkj3OmHKjSw9pvf3faffLLNk="
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
        "0x006e-nix.cachix.org-1:JV0ESHZ7I9+ihTkFJ81RtqsjzV/2845VPwpU8OD8JL8="
      ];
    };
  };

  nixpkgs = {
    overlays = [ inputs.niri.overlays.niri ];
    config.allowUnfree = true;
  };

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 3;
      };
      efi.canTouchEfiVariables = true;
      timeout = 0;
    };
    kernelPackages = pkgs.linuxPackages_cachyos-gcc;
    extraModulePackages = [
      uvcvideo-kernel-module
      acer-wmi-battery-kernel-module
    ];
    blacklistedKernelModules = [
      "iTCO_wdt"
      "iTCO_vendor_support"
    ];
    kernelModules = [
      "acer-wmi-battery"
      "coretemp"
    ];
    extraModprobeConfig = ''
      options iwlmvm power_scheme=2
      options iwlwifi 11n_disable=8
      options acer_wmi_battery enable_health_mode=1
    '';
    resumeDevice = "/dev/dm-0";
    kernelParams = [
      "nowatchdog"
      "resume_offset=1058048"
      "nvidia_drm.fbdev=1"
    ];
    kernel.sysctl = {
      "vm.admin_reserve_kbytes" = 1048576;
      "vm.oom_kill_allocating_task" = 1;
      "kernel.sysrq" = 438;
      "vm.dirty_writeback_centisecs" = 6000;
      "vm.dirty_background_ratio" = 5;
      "vm.dirty_ratio" = 10;
    };
  };

  networking = {
    hostName = "ntsv";
    networkmanager.enable = true;
    nameservers = [ "100.100.100.100" ];
    firewall.enable = false;
  };

  time = {
    timeZone = "Asia/Kolkata";
    hardwareClockInLocalTime = true;
  };

  services = {
    pulseaudio.enable = false;
    battery-notifier = {
      enable = true;
      settings = {
        interval_ms = 3000;
        reminder = {
          threshold = 30;
        };
        threat = {
          threshold = 20;
        };
        warn = {
          threshold = 25;
        };
      };
    };

    gnome.gcr-ssh-agent.enable = false;
    flatpak = {
      enable = true;
      remotes = [
        {
          name = "flathub-beta";
          location = "https://flathub.org/beta-repo/flathub-beta.flatpakrepo";
        }
      ];
      packages = [
        {
          appId = "com.stremio.Stremio";
          origin = "flathub-beta";
        }
      ];
    };
    speechd.enable = lib.mkForce false;
    kanata = {
      enable = false; # Disabled because of errors

      keyboards.default.configFile = ./homerow-mods.kdb;
    };
    scx = {
      enable = true;
      package = pkgs.scx.full;
      scheduler = "scx_lavd";
      extraArgs = [ "--autopower" ];
    };
    tailscale.enable = true;
    resolved.enable = true;
    bpftune.enable = true;
    ananicy = {
      enable = false;
      package = pkgs.ananicy-cpp;
      rulesProvider = pkgs.ananicy-rules-cachyos_git;
    };
    fwupd.enable = true;
    desktopManager.gnome.enable = true;

    displayManager.gdm.enable = true;

    printing.enable = true;
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
      wireplumber = {
        package = pkgs.wireplumber;
        extraConfig = {
          "disable-camera" = {
            "wireplumber.profiles".main."monitor.libcamera" = "disabled";
          };
          "monitor.bluez.properties" = {
            "bluez5.enable-sbc-xq" = true;
            "bluez5.enable-msbc" = true;
            "bluez5.enable-hw-volume" = true;
            "bluez5.roles" = [
              "hsp_hs"
              "hsp_ag"
              "hfp_hf"
              "hfp_ag"
            ];
          };
        };
      };
    };
    libinput.enable = true;
    power-profiles-daemon.enable = false;
    thermald.enable = true;

    auto-cpufreq = {
      enable = true;
      settings = {
        battery = {
          governor = "powersave";
          turbo = "never";
          energy_perf_bias = "power";
          energy_performance_preference = "power";
        };
        charger = {
          governor = "performance";
          turbo = "auto";
        };
      };
    };
    udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="pci", DRIVER=="pcieport", ATTR{power/wakeup}="disabled"


      ACTION=="add", SUBSYSTEM=="usb", TEST=="power/autosuspend", ATTR{idVendor}=="17ef", ATTR{idProduct}=="60ff", ATTR{power/autosuspend}="0"
      ACTION=="add", SUBSYSTEM=="usb", TEST=="power/autosuspend_delay_ms", ATTR{idVendor}=="17ef", ATTR{idProduct}=="60ff", ATTR{power/autosuspend_delay_ms}="0"
      ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{idVendor}=="17ef", ATTR{idProduct}=="60ff", ATTR{power/control}="on"

      ACTION=="add", SUBSYSTEM=="usb", TEST=="power/autosuspend", ATTR{idVendor}=="1ea7", ATTR{idProduct}=="0066", ATTR{power/autosuspend}="0"
      ACTION=="add", SUBSYSTEM=="usb", TEST=="power/autosuspend_delay_ms", ATTR{idVendor}=="1ea7", ATTR{idProduct}=="0066", ATTR{power/autosuspend_delay_ms}="0"
      ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{idVendor}=="1ea7", ATTR{idProduct}=="0066", ATTR{power/control}="on"

      SUBSYSTEM=="pci", ATTR{power/control}="auto"
    '';
  };
  security.pam.services.hyprlock = { };

  programs = {
    corectrl.enable = true;
    nix-index-database.comma.enable = true;

    nix-index = {
      enable = true;
      enableBashIntegration = true;
    };
    nh = {
      enable = true;
      clean = {
        enable = true;
        extraArgs = "--keep-since 3d --keep 3";
      };
      flake = "/home/nithin/nix";
    };
    regreet.enable = false;
    niri = {
      enable = true;
      package = pkgs.niri-unstable;
    };
    dconf.enable = true;
  };
  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 16 * 1024;
    }
  ];

  zramSwap = {
    enable = true;
    memoryPercent = 100;
    priority = 10;
  };

  security.rtkit.enable = true;

  users.users.nithin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  environment = {
    systemPackages = with pkgs; [
      rquickshare
      pciutils
      usbutils
      lm_sensors
      powertop
      commit-mono
      vim
      kvmtool
      xwayland
      wget
      libnotify
      git-crypt
      devenv
      wl-clipboard
      wayland-utils
      libsecret
      deluge
      shotwell
      krita
    ];
    sessionVariables = {
      VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json";
      NIXOS_OZONE_WL = "1";
      EDITOR = "nvim";
      WLR_NO_HARDWARE_CURSORS = "1";
      QT_QPA_PLATFORM = "wayland";
      NH_NO_CHECKS = 1;
    };
    etc."nix/nix.custom.conf".text = ''
      eval-cores = 0
    '';
  };

  systemd = {
    settings.Manager = {
      DefaultTimeoutStopSec = "10s";
    };
    user.extraConfig = "DefaultTimeoutStopSec=10s";
    sleep.extraConfig = ''
      MemorySleepMode=deep
    '';
  };

  powerManagement = {
    enable = true;
    powertop.enable = true;
  };

  hardware = {
    uinput.enable = true;
    cpu.intel.updateMicrocode = true;
  };

  system.stateVersion = "24.05";
}
