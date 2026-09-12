{ delib, pkgs, ... }:
delib.module {
  name = "programs.cli";
  options = delib.singleEnableOption true;

  home.ifEnabled =
    { myconfig, ... }:
    {
      programs = {
        rclone.enable = true;

        atuin = {
          enable = true;
          enableBashIntegration = true;
          settings = {
            style = "compact";
            inline_height = 40;
            enter_accept = false;
          };
        };

        git = {
          enable = true;
          signing = {
            signByDefault = true;
            key = null;
          };
          settings = {
            commit.gpgsign = true;
            tag.gpgSign = true;
            user = {
              name = myconfig.constants.userfullname;
              email = myconfig.constants.useremail;
            };
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
            export DISPLAY=${myconfig.constants.xwaylandDisplay}
            export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin"

            # Binary-cache verdict memo: tree state + timestamp, so repeated
            # switches are instant and only re-evaluate when the tree changes
            # or the verdict ages out (CI keeps pushing after a commit,
            # flipping BUILD -> CACHED with no local change).
            nixos_cache_max_age=600
            nixos_cache_state_file="/tmp/nixos-toplevel-cache-$USER.state"

            # Prints a one-line verdict for the current flake's toplevel and
            # returns 0 (fully cached), 1 (builds needed) or 2 (unknown).
            # Memoized per tree state, re-evaluated at most every
            # $nixos_cache_max_age seconds. Fail-open: unknown proceeds.
            nixos-cache-verdict() {
              local tree_id now last_check last_tree last_verdict
              tree_id="$(git -C ~/nix rev-parse HEAD 2>/dev/null):$(git -C ~/nix status --porcelain 2>/dev/null | sha256sum | cut -d' ' -f1)"
              now=$(date +%s)
              if [ -f "$nixos_cache_state_file" ]; then
                read -r last_check last_tree last_verdict < "$nixos_cache_state_file"
                if [ "$last_tree" = "$tree_id" ] && [ "$((now - last_check))" -lt "$nixos_cache_max_age" ]; then
                  echo "$last_verdict"
                  [ "$last_verdict" = CACHED ] && return 0
                  return 1
                fi
              fi
              local plan built fetchline verdict rc
              if ! plan=$(nix build ~/nix#nixosConfigurations.ntsv.config.system.build.toplevel --dry-run --no-link 2>&1); then
                echo "cache check: evaluation failed, proceeding blind:" >&2
                echo "$plan" | tail -n 5 >&2
                return 2
              fi
              built=$(echo "$plan" | grep -oP 'these \K[0-9]+(?= derivations? will be built)' | head -n 1)
              built=${built:-0}
              if [ "$built" -eq 0 ]; then
                verdict=CACHED
                rc=0
              else
                fetchline=$(echo "$plan" | grep -m1 "will be fetched")
                verdict="BUILD $built derivations"
                [ -n "$fetchline" ] && verdict="$verdict ($fetchline)"
                rc=1
              fi
              echo "$now $tree_id $verdict" > "$nixos_cache_state_file"
              echo "$verdict"
              return $rc
            }

            # Guardrail: refuse OS rebuilds when the ESP is nearly full.
            # A full /boot silently swallows new boot entries (seen: three
            # generations staged with no UKIs installed, machine stuck
            # booting the old generation). Needs ~150MB free for UKI+staging.
            _esp-ok() {
              local min_kb=153600 avail
              avail=$(df --output=avail -k /boot 2>/dev/null | tail -n 1)
              if [ -z "$avail" ]; then
                echo "warning: cannot read /boot usage, skipping ESP check" >&2
              elif [ "$avail" -lt "$min_kb" ]; then
                echo "Refusing: only $((avail / 1024))MB free on /boot (need 150MB)." >&2
                echo "Free space first (old UKIs/staging under /boot/EFI), then retry." >&2
                return 1
              fi
            }
            nh-guarded() {
              _esp-ok || return 1
              command nh "$@"
            }
            rs() {
              _esp-ok || return 1
              local verdict rc
              verdict=$(nixos-cache-verdict); rc=$?
              if [ $rc -eq 0 ]; then
                echo "toplevel fully cached — fast switch, no local build."
              elif [ $rc -eq 1 ]; then
                echo "WARNING: $verdict"
                read -r -p "Switch anyway (builds locally)? [y/N] " ans
                case "$ans" in
                  [Yy]*) ;;
                  *) echo "aborted."; return 1;;
                esac
              else
                echo "cache state unknown — proceeding blind."
              fi
              command nh os switch ~/nix "$@"
            }
            rb() {
              _esp-ok || return 1
              local verdict rc
              verdict=$(nixos-cache-verdict); rc=$?
              if [ $rc -eq 0 ]; then
                echo "toplevel fully cached — fast switch, no local build."
              elif [ $rc -eq 1 ]; then
                echo "WARNING: $verdict"
                read -r -p "Switch anyway (builds locally)? [y/N] " ans
                case "$ans" in
                  [Yy]*) ;;
                  *) echo "aborted."; return 1;;
                esac
              else
                echo "cache state unknown — proceeding blind."
              fi
              command nh os boot ~/nix "$@"
            }
          '';
          shellAliases = {
            mc = "pushd ~/nix;nvim ~/nix;popd";
            k = "kubectl";
            urldecode = "python3 -c 'import sys, urllib.parse as ul; print(ul.unquote_plus(sys.stdin.read()))'";
            urlencode = "python3 -c 'import sys, urllib.parse as ul; print(ul.quote_plus(sys.stdin.read()))'";
          };
        };
      };
    };
}
