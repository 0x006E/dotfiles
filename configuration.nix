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

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 3;
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
  '';

  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 16 * 1024;
    }
  ]; # 16GB Swap
  boot.resumeDevice = "/dev/dm-0"; # the unlocked drive mapping
  boot.kernelParams = [
    "i915.enable_psr=0"
    "nowatchdog"
    "resume_offset=1058048" # for hibernate resume
  ];

  chaotic.scx.enable = true;
  # chaotic.scx.scheduler = "scx_bpfland";
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
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
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
      "https://walker.cachix.org"
      "https://0x006e-nix.cachix.org"
    ];
    trusted-public-keys = [
      "walker.cachix.org-1:fG8q+uAaMqhsMxWjwvk0IMb4mFPFLqHjuvfwQxE4oJM="
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
  services.auto-cpufreq.enable = true;
  programs.dconf.enable = true;
  hardware.cpu.intel.updateMicrocode = true; 
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT VK_DRIVER_FILES="/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json"upgrade your system.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?
}
