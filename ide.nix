{
  lib,
  pkgs,
  ...
}:

{

  home.packages = with pkgs; [
    gcc
    hugo
    mkcert
    nixfmt-rfc-style
    node2nix
    nodejs
    nodePackages.svelte-language-server
    nodePackages.typescript-language-server
    npm-check-updates
    php
    pyright
    (sqlite.override { interactive = true; })
    xh
  ];

  programs.nixvim = {
    enable = true;
    vimAlias = true;
    autoCmd = [
      {
        event = [ "BufWritePre" ];
        pattern = [ "*" ];
        command = "lua vim.lsp.buf.format()";
      }
    ];
    globals.mapleader = " ";
    colorschemes.kanagawa = {
      enable = true;
      settings = {
        transparent = true;
      };
    };
    opts = {
      number = true;
      shiftwidth = 2;
      wildmenu = true;
      wildmode = "longest:full,full";
      clipboard = "unnamedplus";
    };
    keymaps = [
      {
        key = "<C-s>";
        action = ":w<cr>";
        mode = [
          "v"
          "n"
          "i"
          "x"
        ];
      }
      {
        key = "<F2>";
        action = "<cmd>Neotree toggle<cr>";
      }
      {
        key = "<space>e";
        action.__raw = "vim.diagnostic.open_float";
      }
      {
        key = "<leader>sh";
        action = ":split<cr>";
      }
      {
        key = "<leader>sv";
        action = ":vsplit<cr>";
      }
      {
        key = "<leader>c";
        action = ''"+yy'';
        mode = [ "n" ];
      }
      {
        key = "<leader>c";
        action = ''"+y'';
        mode = [ "v" ];
      }
    ];

    plugins = {
      leap.enable = true;
      which-key.enable = true;
      sleuth.enable = true;
      neo-tree.enable = true;
      oil.enable = true;
      nix.enable = true;
      nvim-colorizer.enable = true;
      fugitive.enable = true;
      gitignore.enable = false;

      treesitter = {
        enable = true;
        settings = {
          highlight.enable = true;
          indent = {
            enable = true;
          };
        };
      };

      telescope = {
        enable = true;
        keymaps = {
          "<leader>ff" = "find_files";
          "<leader>fg" = "live_grep";
          "<leader>fb" = "buffers";
        };
      };

      lsp = {
        enable = true;
        servers = {
          ts-ls.enable = true;
          gopls.enable = true;
          svelte.enable = true;
          tailwindcss.enable = true;
          pyright.enable = true;
          nixd = {
            enable = true;
            settings = {
              nixpkgs = {
                expr = "import <nixpkgs> { }";
              };
              formatting = {
                command = [ "nixfmt" ];
              };
              options = {
                nixos = {
                  expr = "(builtins.getFlake (\"git+file://\" + toString ./.)).nixosConfigurations.ntsv.options";
                };
                home_manager = {
                  expr = "(builtins.getFlake (\"git+file://\" + toString ./.)).homeConfigurations.\"nithin@ntsv\".options";
                };
              };
            };
          };
        };
        keymaps = {
          lspBuf = {
            K = "hover";
            gD = "references";
            gd = "definition";
            gi = "implementation";
            gt = "type_definition";
          };
          diagnostic = {
            "<leader>j" = "goto_next";
            "<leader>k" = "goto_prev";
          };
        };
      };

      cmp = {
        enable = true;
        autoEnableSources = true;
        settings = {
          completion = {
            keyword_length = 2;
          };
          sources = [
            { name = "nvim_lsp"; }
            { name = "luasnip"; }
            { name = "path"; }
            { name = "buffer"; }
          ];
          mapping = {
            "<C-Space>" = "cmp.mapping.complete()";
            "<C-e>" = "cmp.mapping.close()";
            "<CR>" = "cmp.mapping.confirm({ select = true })";
            "<S-Tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
            "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
          };
        };
      };
    };
  };
}
