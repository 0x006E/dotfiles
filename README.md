# NTSV NixOS Configuration

A highly modular, declarative NixOS configuration built on top of the [Denix](https://github.com/yunfachi/denix) architecture using `delib`.

## 🌟 Key Features

- **Architecture**: Flake-based, highly decoupled module system using `delib`.
- **Window Manager**: [Niri](https://github.com/YaLTeR/niri) - A scrollable-tiling Wayland compositor.
- **Desktop Shell**: [Noctalia Shell](https://github.com/noctalia/shell) - A custom desktop environment built on Quickshell.
- **Theming**: System-wide dynamic theming powered by [Stylix](https://github.com/danth/stylix).
- **Secure Boot**: Integrated [Lanzaboote](https://github.com/nix-community/lanzaboote) with TPM/BitLocker support.
- **Editor**: Fully modularized Neovim setup using [NixVim](https://github.com/nix-community/nixvim).
- **Browser**: Zen Browser natively integrated via Home Manager.
- **Boot Management**: Plymouth splash screen with silent boot parameters.
- **Custom Packages**: Includes out-of-tree kernel modules (`uvcvideo` patch, `acer-wmi-battery`).

## 📂 Folder Structure

```text
.
├── flake.nix               # Flake entrypoint and inputs
├── hosts/
│   └── ntsv/               # Primary desktop host configuration
├── modules/                # Denix modular configuration
│   ├── config/             # Base Home Manager & User configurations
│   ├── core/               # System core (Boot, Nix, Networking, SecureBoot)
│   ├── desktop/            # Niri, Noctalia, Stylix, Fonts, Kanshi
│   ├── hardware/           # NVIDIA, Audio, Power Management, Kanata
│   ├── programs/           # Browsers, Media, NixVim, CLI tools, GPG
│   └── services/           # Virtualization, Printing, Desktop Services
├── nixvim-config/          # Modular NixVim configuration (keymaps, plugins)
├── overlays/               # Nixpkgs overlays
├── pkgs/                   # Custom packages and kernel module derivations
└── rices/                  # Theme definitions (Dark/Light) and wallpapers
```

## 🚀 Managing the System

This configuration uses [`nh`](https://github.com/viperML/nh) (Nix Helper) for fast and easy system management.

**Apply Configuration (Switch):**
```bash
nh os switch ~/nix
```

**Build Next Generation (Boot):**
```bash
nh os boot ~/nix
```

**Update Flake Inputs:**
```bash
nix flake update
```

## 🛠️ Notable Hardware & Service Configurations

- **Power Management**: Integrates `auto-cpufreq`, `thermald`, and `powertop` with strict USB/PCIe autosuspend udev rules for maximizing battery life.
- **Hardware**: Custom kernel modules for Acer WMI battery control and UVC video driver patches.
- **Virtualization**: Pre-configured `virt-manager` and `qemu` setup with automatic system connections.
- **Keyboard**: Kanata keyboard remapping module (currently configured with Homerow Mods, toggleable in `modules/hardware/kanata.nix`).

## 🤝 Acknowledgments
- Module architecture powered by [Denix](https://github.com/yunfachi/denix).
