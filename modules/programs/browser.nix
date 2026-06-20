{ delib, inputs, ... }:
delib.module {
  name = "programs.browser";

  home.always = { myconfig, ... }: { pkgs, config, lib, ... }: {
    imports = [ inputs.zen-browser.homeModules.beta ];
    programs.zen-browser = {
      enable = true;
      profiles = {
        "${myconfig.constants.username}" = {
          id = 0;
          name = "${myconfig.constants.username}";
          path = "${myconfig.constants.username}.default";
          isDefault = true;
          settings = {
            "signon.rememberSignons" = false;
            "af.sidebery.edgyarc-theme" = true;
            "browser.cache.jsbc_compression_level" = 3;
            "dom.enable_web_task_scheduling" = true;
            "gfx.canvas.accelerated" = true;
            "gfx.canvas.accelerated.cache-item" = 4096;
            "gfx.canvas.accelerated.cache-size" = 512;
            "gfx.content.skia-font-cache-size" = 20;
            "image.mem.decode_bytes_at_a_time" = 32768;
            "layout.css.color-mix.enabled" = true;
            "layout.css.grid-template-masonry-value.enabled" = true;
            "layout.css.has-selector.enabled" = true;
            "layout.css.light-dark.enabled" = true;
            "media.cache_readahead_limit" = 7200;
            "media.cache_resume_threshold" = 3600;
            "media.memory_cache_max_size" = 65536;
            "network.dnsCacheExpiration" = 3600;
            "network.dns.disablePrefetch" = true;
            "network.dns.disablePrefetchFromHTTPS" = true;
            "network.http.max-connections" = 1800;
            "network.http.max-persistent-connections-per-server" = 10;
            "network.http.max-urgent-start-excessive-connections-per-host" = 5;
            "network.http.pacing.requests.enabled" = false;
            "network.predictor.enabled" = false;
            "network.prefetch-next" = false;
            "network.ssl_tokens_cache_capacity" = 10240;
            "svg.context-properties.content.enabled" = true;
            "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
            "uc.tweak.af.greyscale-webext-icons" = true;
            "uc.tweak.floating-tabs" = true;
            "uc.tweak.hide-forward-button" = true;
            "uc.tweak.hide-tabs-bar" = true;
            "uc.tweak.rounded-corners" = true;
            "widget.macos.titlebar-blend-mode.behind-window" = true;
          };
        };
      };
      policies = {
        PasswordManagerEnabled = false;
        ExtensionSettings =
          with builtins;
          let
            extension = shortId: uuid: {
              name = uuid;
              value = {
                install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
                installation_mode = "normal_installed";
              };
            };
          in
          listToAttrs [
            (extension "ublock-origin" "uBlock0@raymondhill.net")
            (extension "bitwarden-password-manager" "{446900e4-71c2-419f-a6a7-df9c091e268b}")
            (extension "2fas-two-factor-authentication" "admin@2fas.com")
            (extension "sponsorblock" "sponsorBlocker@ajay.app")
            (extension "dearrow" "deArrow@ajay.app")
            (extension "enhancer-for-youtube" "enhancerforyoutube@maximerf.addons.mozilla.org")
            (extension "tabliss" "extension@tabliss.io")
            (extension "don-t-fuck-with-paste" "DontFuckWithPaste@raim.ist")
            (extension "clearurls" "{74145f27-f039-47ce-a470-a662b129930a}")
            (extension "react-devtools" "@react-devtools")
          ];
      };
    };

    home.packages = with pkgs; [
      google-chrome
    ];
  };
}
