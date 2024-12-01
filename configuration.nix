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
    ./fingerprint.nix
  ];

  nix = {
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    settings = {
      auto-optimise-store = true;
      trusted-users = [
        "root"
        "@wheel"
      ];
      substituters = [
        "https://cache.garnix.io"
        "https://0x006e-nix.cachix.org"
      ];
      trusted-public-keys = [
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
    kernelPackages = pkgs.linuxPackagesFor (
      pkgs.linuxPackages_latest.kernel.override {
        structuredExtraConfig = with lib.kernel; {
          SCHED_CLASS_EXT = yes;
        };
        ignoreConfigErrors = false;
      }
    );

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
      options iwlwifi 11n_disable=8 
    '';
    resumeDevice = "/dev/dm-0";
    kernelParams = [
      "nowatchdog"
      "resume_offset=1058048"
    ];
    kernel.sysctl = {
      "vm.admin_reserve_kbytes" = 1048576;
      "vm.oom_kill_allocating_task" = 1;
      "kernel.sysrq" = 438;
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
    speechd.enable = lib.mkForce false;
    kanata = {
      enable = false; # Disabled because of errors

      keyboards.default.configFile = ./homerow-mods.kdb;
    };
    scx = {
      enable = true;
      package = pkgs.scx.full;
      scheduler = "scx_bpfland";
      extraArgs = [ ];
    };
    kmscon = {
      enable = true;
      hwRender = true;
      fonts = [
        {
          name = "CommitMono Nerd Font";
          package = pkgs.nerd-fonts.commit-mono;
        }
      ];
    };
    tailscale.enable = true;
    resolved.enable = true;
    bpftune.enable = true;
    ananicy = {
      enable = true;
      package = pkgs.ananicy-cpp;
      rulesProvider = pkgs.ananicy-rules-cachyos_git;
    };
    fwupd.enable = true;
    xserver = {
      enable = true;
      displayManager.lightdm.enable = true;
      desktopManager.cinnamon.enable = true;

    };
    greetd = {
      enable = false;
      greeterManagesPlymouth = false;
      settings.default_session = {
        command = ''
          ${lib.makeBinPath [ pkgs.cage ]}/cage -s -- ${
            lib.makeBinPath [ config.programs.regreet.package ]
          }/regreet
        '';
        user = "greeter";
      };
    };
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
    tlp.enable = true;
  };

  programs = {
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
      comma
      lm_sensors
      commit-mono
      vim
      kvmtool
      xwayland
      wget
      libnotify
      nil
      wireguard-tools
      git-crypt
      devenv
      wl-clipboard
      wayland-utils
      libsecret
      cage
      dwarfs
      deluge
      darktable
      shotwell
      krita
      zed-editor
      windsurf
    ];
    sessionVariables = {
      VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json";
      NIXOS_OZONE_WL = "1";
      EDITOR = "nvim";
      WLR_NO_HARDWARE_CURSORS = "1";
      QT_QPA_PLATFORM = "wayland";
    };
  };

  systemd = {
    extraConfig = "DefaultTimeoutStopSec=10s";
    user.extraConfig = "DefaultTimeoutStopSec=10s";
  };

  powerManagement = {
    enable = true;
    powertop.enable = true;
  };

  hardware = {
    pulseaudio.enable = false;
    uinput.enable = true;
    cpu.intel.updateMicrocode = true;
  };

  system.stateVersion = "24.05";
}
