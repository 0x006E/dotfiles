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
            export PATH="$PATH:$HOME/bin=$HOME/.local/bin:$HOME/go/bin"

            # Guardrail: refuse OS rebuilds when the ESP is nearly full.
            # A full /boot silently swallows new boot entries (seen: three
            # generations staged with no UKIs installed, machine stuck
            # booting the old generation). Needs ~150MB free for UKI+staging.
            nh-guarded() {
              local min_kb=153600 avail
              avail=$(df --output=avail -k /boot 2>/dev/null | tail -n 1)
              if [ -z "$avail" ]; then
                echo "warning: cannot read /boot usage, skipping ESP check" >&2
              elif [ "$avail" -lt "$min_kb" ]; then
                echo "Refusing: only $((avail / 1024))MB free on /boot (need 150MB)." >&2
                echo "Free space first (old UKIs/staging under /boot/EFI), then retry." >&2
                return 1
              fi
              command nh "$@"
            }
            rs() { nh-guarded os switch ~/nix "$@"; }
            rb() { nh-guarded os boot ~/nix "$@"; }
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
