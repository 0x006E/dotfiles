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
- Feature modules follow the enable-option pattern:
  ```nix
  { delib, inputs, pkgs, lib, config, ... }:   # header args are used by ifEnabled bodies
  delib.module {
    name = "category.name";                    # must match the enable-option path
    options = delib.singleEnableOption true;   # toggled per host in hosts/ntsv/default.nix
    nixos.always = { imports = [ inputs.X.nixosModules.X ]; };  # unconditional imports only
    nixos.ifEnabled = { myconfig, cfg, ... }: { ... };          # pure option definitions
    home.ifEnabled  = { myconfig, cfg, ... }: { ... };
  }
  ```
- Rules learned the hard way:
  - `ifEnabled`/`ifDisabled` values are wrapped in `lib.mkIf` → they must be plain option definitions. No `imports` key and no bare lambda-modules inside them (denix routes mkIf-wrapped values as option definitions).
  - Need HM-scoped args (e.g. `config.lib.niri.actions`) or a lambda-module? Wrap it: `ifEnabled = {...}: { imports = [ ({ pkgs, ... }: ...) ]; }`.
  - Pure infrastructure (`config/*`, `core/*`, `services/sops`, overlays wiring in `core.overlays`) stays unconditional `.always`.
  - File-header args (`pkgs`, `lib`, `inputs`, …) come from top-level NixOS moduleArgs — for HM-only values (like per-user `config.lib.*`) use an inner lambda instead.
- Shared values live in `modules/config/constants.nix`; access via `myconfig.constants.username` etc.
- Hosts use `delib.host` (`hosts/ntsv/default.nix`) which picks the active `rice` (theme) and carries the explicit feature-enable manifest. Rices are `delib.rice` modules under `rices/{dark,light}/` (Stylix base16 scheme, GTK/cursor theming).
- All modules receive extra args from `specialArgs`: `inputs`, `pkgs-stable`, `pkgs-small` (nixos-unstable-small), `self`, `system`. Use these instead of re-importing channels.
- Home Manager user is hardcoded as `nithin` (`homeManagerUser` in `flake.nix`, mirrors `constants.username`).

## Packages & overlays wiring

- `overlays/default.nix` is a **pure data file** returning the overlay list; consumed twice: by `modules/desktop/extra.nix` (`nixpkgs.overlays`) and by `flake.nix` (standalone `pkgs-ci` for exporting `papers`/`inkscape`/`catppuccin-cursors` to the CI matrix without evaluating the host). Don't turn it back into a module.
- `pkgs/default.nix` is consumed twice: as flake `packages` output **and** injected as one of those overlays. Custom vim plugins (`pkgs/vimPlugins/`) become available as `pkgs.vimPlugins.<name>` everywhere.
- Flake `githubActions` matrix is generated from `self.packages` — anything added to `pkgs/default.nix` is automatically CI-built and pushed to Cachix (`0x006e-nix`).
- Modules needing sibling data files use directory modules (`wgcf/default.nix` + `wgcf/add.sh`, like `gpg/`, `wayprompt/`). A bare `foo.nix` beside a new `foo/` dir breaks flake lazy-tree path resolution.

## Secrets

- Global sops defaults (module import, `defaultSopsFile`, age key) live in `modules/services/sops.nix`; feature modules only declare their own `sops.secrets.*`.
- sops-nix with age; `secrets/*.yaml` encrypted to the host key listed in `.sops.yaml`. Cannot decrypt or edit outside the `ntsv` host.

## Docs lookup

- When you need to search docs (libraries, frameworks, APIs — Noctalia, niri, Stylix, NixVim, Home Manager, etc.), use the `context7` tools before guessing option names or schemas from memory.
- For Nix questions — nix options (NixOS / home-manager / nix-darwin / nixvim), packages, flakes, channels — use the `nix` tools.

## Conventions

- Commit style: conventional commits (`feat(scope):`, `fix(scope):`).
- `[create-pull-request] automated change` / `flake.lock: Update` commits come from CI auto-update workflows — don't recreate manually.
