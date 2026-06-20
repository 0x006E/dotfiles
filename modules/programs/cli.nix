{ delib, ... }:
delib.module {
  name = "programs.cli";

  home.always = { myconfig, ... }: { pkgs, config, lib, ... }: {
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
          export DISPLAY=:12
          export PATH="$PATH:$HOME/bin=$HOME/.local/bin:$HOME/go/bin"
        '';
        shellAliases = {
          mc = "pushd ~/nix;nvim ~/nix;popd";
          rs = "nh os switch ~/nix ";
          rb = "nh os boot ~/nix ";
          k = "kubectl";
          urldecode = "python3 -c 'import sys, urllib.parse as ul; print(ul.unquote_plus(sys.stdin.read()))'";
          urlencode = "python3 -c 'import sys, urllib.parse as ul; print(ul.quote_plus(sys.stdin.read()))'";
        };
      };
    };
  };
}
