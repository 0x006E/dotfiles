# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  pkgs,
  inputs,
  pkgs-stable,
  ...
}: let
  uvcvideo-kernel-module = pkgs.linuxPackages_cachyos-lto.callPackage ./uvcvideo-kernel-module.nix {};
  acer-wmi-battery-kernel-module = pkgs.linuxPackages_cachyos-lto.callPackage ./acer-wmi-battery.nix {};
in {
  nix = {
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./nvidia.nix
    ./font.nix
    ./plymouth.nix
    ./virtualization.nix
    ./printing.nix
    # ./fingerprint.nix
  ];

  nixpkgs.overlays = [inputs.niri.overlays.niri];
  nixpkgs.config.allowUnfree = true;
  # services.desktopManager.cosmic.enable = true;
  # services.displayManager.cosmic-greeter.enable = true;
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.loader.systemd-boot.timeout = 0;
  nix.settings.auto-optimise-store = true;
  nix.settings.trusted-users = ["root" "@wheel"];
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 3d";
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_cachyos-lto;
  boot.extraModulePackages = [uvcvideo-kernel-module acer-wmi-battery-kernel-module];
  boot.blacklistedKernelModules = ["iTCO_wdt" "iTCO_vendor_support"];
  boot.kernelModules = ["acer-wmi-battery"];
  boot.extraModprobeConfig = ''
    options acer-wmi-battery enable_health_mode=1
    options iwlwifi 11n_disable=8 power_save="Y" power_level=5
  '';
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos;
  };
  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 16 * 1024;
    }
  ]; # 16GB Swap
  boot.resumeDevice = "/dev/dm-0"; # the unlocked drive mapping
  boot.kernelParams = [
    "nowatchdog"
    "resume_offset=1058048" # for hibernate resume
  ];

  chaotic.scx.enable = true;
  chaotic.scx.scheduler = "scx_bpfland";
  services.fwupd.enable = true;
  networking.hostName = "ntsv"; # Define your hostname.
  # Pick only one oOh well, i'll close this for now then!f the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "Asia/Kolkata";
  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  boot.kernel.sysctl."kernel.sysrq" = 438;

  zramSwap.enable = true;
  zramSwap.memoryPercent = 100;
  zramSwap.priority = 10;

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.displayManager.gdm.wayland = true;
  services.xserver.desktopManager.gnome.enable = true;
  #  services.spice-vdagentd.enable = true;
  #  services.qemuGuest.enable = true;

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  services.printing.enable = true;
  hardware.pulseaudio.enable = false;
  # Enable sound.
  security.rtkit.enable = true;
  services.pipewire = {
    # wireplumber.package = pkgs-stable.wireplumber;
    wireplumber = {
      package = pkgs-stable.wireplumber;
      extraConfig = {
        "disable-camera" = {
          "wireplumber.profiles" = {
            main = {
              "monitor.libcamera" = "disabled";
            };
          };
        };
      };
    };
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;
  };
  services.pipewire.wireplumber.extraConfig = {
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

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.nithin = {
    isNormalUser = true;
    extraGroups = ["wheel"]; # Enable ‘sudo’ for the user.
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    commit-mono
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    xwayland
    inputs.zen-browser.packages."${system}".specific
    wget
    libnotify
    nil
    scx
    wireguard-tools
    git-crypt
    devenv
    wl-clipboard
    wayland-utils
    libsecret
    cage
    gamescope
    dwarfs
    deluge
    zed-editor
    darktable
    shotwell
    krita
  ];
  nix.settings = {
    substituters = [
      "https://cache.garnix.io"
      "https://walker-git.cachix.org"
      "https://0x006e-nix.cachix.org"
    ];
    trusted-public-keys = [
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "walker-git.cachix.org-1:vmC0ocfPWh0S/vRAQGtChuiZBTAe4wiKDeyyXM0/7pM="
      "0x006e-nix.cachix.org-1:JV0ESHZ7I9+ihTkFJ81RtqsjzV/2845VPwpU8OD8JL8="
    ];
  };
  systemd.extraConfig = ''DefaultTimeoutStopSec=10s'';
  systemd.user.extraConfig = ''DefaultTimeoutStopSec=10s'';
  # nixpkgs.overlays = [inputs.niri.overlays.niri];
  time.hardwareClockInLocalTime = true;
  programs.niri.enable = true;
  programs.niri.package = pkgs.niri-unstable;
  environment.sessionVariables = {
    VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json";
    NIXOS_OZONE_WL = "1";
    EDITOR = "nvim";
    WLR_NO_HARDWARE_CURSORS = "1";
    #   DISPLAY = ":0"; # Adding this to session variables breaks everything
    QT_QPA_PLATFORM = "wayland";
  };
  services.power-profiles-daemon.enable = false;
  # services.auto-cpufreq.enable = true;
  services.thermald.enable = true;
  powerManagement.enable = true;
  powerManagement.powertop.enable = true;
  services.tlp = {
    enable = true;
    # settings = {
    #   TLP_DEFAULT_MODE = "BAT";
    #   TLP_PERSISTENT_DEFAULT = 1;
    # };
  };
  programs.dconf.enable = true;
  hardware.cpu.intel.updateMicrocode = true;
  system.stateVersion = "24.05"; # Did you read the comment?
}
