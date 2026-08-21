# AGENTS.md

NixOS flake configuration (single host `ntsv`, x86_64-linux) built on the [Denix](https://github.com/yunfachi/denix) module system (`delib`). Not an app repo — no test suite; verification = format + `nix flake check` + building.

## Commands

```bash
nix fmt                  # format all *.nix (nixfmt; also enforced by pre-commit hook)
nix flake check          # CI gate (.github/workflows/check-flake.yml)
nix build .#<pkg>        # build one package from pkgs/
nh os switch ~/nix       # apply system config (or `nh os boot`)
nix flake update         # update inputs (CI also does this daily via PR)
nix develop              # shell with nil, nixd, nixfmt, statix, deadnix, pre-commit
```

## Denix architecture

- `flake.nix` passes `paths = [ ./hosts ./modules ./rices ]` to denix — files in those dirs are **auto-discovered**; never maintain import lists.
- Modules follow the pattern:
  ```nix
  { delib, inputs, ... }:
  delib.module {
    name = "category.name";            # e.g. "desktop.niri", "hardware.nvidia"
    nixos.always = { myconfig, ... }: { ... };  # NixOS-level config
    home.always   = { myconfig, ... }: { ... }; # Home Manager-level config
  }
  ```
- Shared values live in `modules/config/constants.nix`; access via `myconfig.constants.username` etc.
- Hosts use `delib.host` (`hosts/ntsv/default.nix`) which picks the active `rice` (theme). Rices are `delib.rice` modules under `rices/{dark,light}/` (Stylix base16 scheme, GTK/cursor theming).
- All modules receive extra args from `specialArgs`: `inputs`, `pkgs-stable`, `pkgs-unstable`, `self`, `system`. Use these instead of re-importing channels.
- Home Manager user is hardcoded as `nithin` (`homeManagerUser` in `flake.nix`).

## Packages & overlays wiring

- `pkgs/default.nix` is consumed twice: as flake `packages` output **and** injected as a nixpkgs overlay (`overlays/default.nix`). Custom vim plugins (`pkgs/vimPlugins/`) become available as `pkgs.vimPlugins.<name>` everywhere.
- Flake `githubActions` matrix is generated from `self.packages` — anything added to `pkgs/default.nix` is automatically CI-built and pushed to Cachix (`0x006e-nix`).

## Secrets

- sops-nix with age; `secrets/*.yaml` encrypted to the host key listed in `.sops.yaml`. Cannot decrypt or edit outside the `ntsv` host.

## Docs lookup

- Use the `context7` MCP server for library/framework/API documentation (Noctalia, niri, Stylix, NixVim, Home Manager options, etc.) before guessing option names or schemas from memory.

## Conventions

- Commit style: conventional commits (`feat(scope):`, `fix(scope):`).
- `[create-pull-request] automated change` / `flake.lock: Update` commits come from CI auto-update workflows — don't recreate manually.
