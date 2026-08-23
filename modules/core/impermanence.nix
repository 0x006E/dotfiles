{
  delib,
  inputs,
  pkgs,
  config,
  lib,
  ...
}:
let
  # $HOME-relative paths bound from /persist by home.persistence below.
  persistHomeDirs = [
    "Desktop"
    "Documents"
    "Downloads"
    "Music"
    "Pictures"
    "Videos"
    "Games"
    "Public"
    "Templates"
    "projects"
    ".ssh"
    ".gnupg"
    "nix"
    ".local/state"
    ".local/share/atuin"
    ".local/share/opencode"
    ".local/share/direnv"
    ".local/share/keybase"
    ".local/share/nvim"
    ".local/share/fonts"
    ".local/share/icons"
    ".local/share/bottles"
    ".local/share/waydroid"
    ".local/share/stremio"
    ".local/share/DBeaverData"
    ".var"
    ".config/dconf"
    ".config/zen"
    ".stremio-server"
  ];
in
delib.module {
  name = "core.impermanence";

  options = delib.singleEnableOption true;

  nixos.always = {
    imports = [ inputs.impermanence.nixosModules.impermanence ];
  };

  nixos.ifEnabled =
    { myconfig, ... }:
    let
      inherit (myconfig.constants) username;
      home = "/home/${username}";
      # systemd auto-creates bind-mount parents as root:root on the wiped
      # root, breaking HM activation; re-assert ownership every boot
      # (impermanence#298).
      parents = lib.unique (
        [ home ]
        ++ map (
          dir:
          let
            parent = dirOf dir;
          in
          if parent == "." then home else "${home}/${parent}"
        ) persistHomeDirs
      );
    in
    {
      systemd.tmpfiles.settings."10-impermanence-home" = builtins.listToAttrs (
        map (dir: {
          name = dir;
          value.d = {
            user = username;
            group = "users";
            mode = if dir == home then "0700" else "0755";
          };
        }) parents
      );

      # Wipe mechanism: recreate the @ root subvolume on every boot.
      # Old roots are kept in @old_roots for 30 days as a safety net.
      # initrdBin already provides coreutils + mount; add what's missing.
      boot.initrd.systemd.extraBin = {
        btrfs = "${pkgs.btrfs-progs}/bin/btrfs";
        find = "${pkgs.findutils}/bin/find";
      };

      boot.initrd.systemd.services.rollback = {
        description = "Reset btrfs root subvolume to a pristine state";
        wantedBy = [ "initrd.target" ];
        after = [ "systemd-cryptsetup@crypted.service" ];
        before = [ "sysroot.mount" ];
        unitConfig.DefaultDependencies = "no";
        serviceConfig.Type = "oneshot";
        script = ''
          mkdir -p /btrfs_tmp
          mount -o subvolid=5 /dev/mapper/crypted /btrfs_tmp

          # Skip the wipe when resuming from hibernation: the marker is
          # written by the system-sleep hook below right before hibernating.
          if [[ -f /btrfs_tmp/@persist/.hibernating ]]; then
            rm -f /btrfs_tmp/@persist/.hibernating
            umount /btrfs_tmp
            exit 0
          fi

          if [[ -e /btrfs_tmp/@ ]]; then
            mkdir -p /btrfs_tmp/@old_roots
            timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/@)" "+%Y-%m-%d_%H:%M:%S")
            mv "/btrfs_tmp/@" "/btrfs_tmp/@old_roots/$timestamp"
          fi

          delete_subvolume_recursively() {
            IFS=$'\n'
            for i in $(btrfs subvolume list -o "$1" | cut -f9- -d' '); do
              delete_subvolume_recursively "/btrfs_tmp/$i"
            done
            btrfs subvolume delete "$1"
          }

          for i in $(find /btrfs_tmp/@old_roots -maxdepth 1 -mtime +30); do
            [[ "$(basename "$i")" == "@old_roots" ]] || delete_subvolume_recursively "$i"
          done

          btrfs subvolume create /btrfs_tmp/@
          umount /btrfs_tmp
        '';
      };

      # Hibernation marker: written pre-hibernate, cleared post-resume, so the
      # initrd rollback unit can skip the wipe when resuming from swap.
      environment.etc."systemd/system-sleep/impermanence-flag".source =
        pkgs.writeShellScript "impermanence-flag" ''
          if [[ "$1" == pre && "$2" == hibernate ]]; then
            touch /persist/.hibernating
          fi
          if [[ "$1" == post && "$2" == hibernate ]]; then
            rm -f /persist/.hibernating
          fi
        '';

      # The rollback resets sudo's lecture tracking every boot.
      security.sudo.extraConfig = "Defaults lecture = never";

      # Keep the conventional flake location working on a fresh root.
      systemd.tmpfiles.rules = [
        "d /etc/nixos 0755 root root - -"
        "L+ /etc/nixos/flake.nix - - - - /home/nithin/nix/flake.nix"
      ];

      environment.persistence."/persist" = {
        enable = true;
        hideMounts = true;

        files = [
          "/etc/machine-id"
        ];

        directories = [
          # Core system state
          "/var/lib/nixos" # UID/GID allocation — critical for stable ownership
          "/var/lib/systemd" # random-seed, timesyncd, coredumps, pcrlock
          "/var/log"

          # Identity & secrets
          "/etc/ssh"
          "/etc/NetworkManager/system-connections"
          {
            directory = config.boot.lanzaboote.pkiBundle; # secure-boot keys (/etc/secureboot)
            mode = "0700";
          }

          # Network
          "/var/lib/NetworkManager"
          "/var/lib/NetworkManager-fortisslvpn"
          "/var/lib/tailscale"

          # GDM reads AccountsService for the greeter user list; without this
          # the list is empty on every fresh boot.
          "/var/lib/AccountsService"

          # Services
          "/var/lib/docker"
          "/var/lib/libvirt"
          "/var/lib/qemu"
          "/var/lib/incus"
          "/var/lib/lxc"
          "/var/lib/lxcfs"
          "/var/lib/flatpak"
          "/var/lib/bluetooth"
          "/var/lib/cups"
          "/var/lib/fprint"
          {
            directory = "/var/lib/colord";
            user = "colord";
            group = "colord";
            mode = "0700";
          }
          "/var/lib/upower"
          "/var/lib/udisks2"
          "/var/lib/power-profiles-daemon"
          "/var/lib/fwupd"
          "/var/lib/geoclue"
          "/var/lib/tlp"
          "/var/lib/waydroid"
          "/var/lib/private" # DynamicUser service state
          "/var/db/sudo/lectured"
        ];
      };
    };

  # Home-manager side: persist selected user state under /persist and
  # surface it as bind mounts inside the ephemeral /home. Entries are
  # relative to $HOME; the NixOS module auto-imports this HM module.
  home.ifEnabled = {
    home.persistence."/persist" = {
      directories = persistHomeDirs;
      files = [
        ".face"
        ".bash_history"
      ];
    };
  };
}
