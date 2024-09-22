{
  pkgs,
  pkgs-unstable,
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
    performance = {
      byteCompileLua = {
        enable = true;
        nvimRuntime = true;
        plugins = true;
      };
    };
    package = pkgs-unstable.neovim-unwrapped;
    autoCmd = [
      {
        event = [ "BufWritePre" ];
        pattern = [ "*" ];
        command = "lua vim.lsp.buf.format()";

      }

      {
        event = [ "VimEnter" ];
        pattern = [ "*" ];
        callback = {
          __raw = "MiniMap.open";
        };
      }
      # {
      #   event = [ "User" ];
      #   pattern = [ "MiniStarterOpened" ];
      #   callback = {
      #     __raw = ''
      #       function()
      #             local rhs = function()
      #               MiniStarter.eval_current_item()
      #               MiniMap.open()
      #             end
      #             vim.keymap.set('n', '<CR>', rhs, { buffer = true })
      #           end
      #     '';
      #   };
      # }
    ];
    globals.mapleader = " ";
    colorschemes.cyberdream = {
      enable = true;
      settings = {
        italic_comments = true;
        transparent = true;
      };
    };
    opts = {
      number = true;
      shiftwidth = 2;
      wildmenu = true;
      wildmode = "longest:full,full";
      clipboard = "unnamedplus";
      # nvim-ufo
      foldenable = true;
      foldcolumn = "auto:9";
      foldlevel = 99;
      foldlevelstart = 99;
      fillchars = "eob: ,fold: ,foldopen:,foldsep: ,foldclose:";
    };
    keymaps = [
      {
        key = "<leader>d";
        action = "\"_d";
        mode = [
          "n"
          "x"
        ];
      }
      {
        key = "<leader>p";
        action = "\"_dP";
        mode = [ "x" ];
      }
      {
        key = "<C-s>";
        action = "<esc>:w<cr>i";
        mode = [
          "i"
        ];

      }
      {
        key = "<C-s>";
        action = "<esc>:w<cr>";
        mode = [
          "v"
          "n"
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
      lualine.enable = true;
      nvim-colorizer.enable = true;
      fugitive.enable = true;
      lazygit.enable = true;
      copilot-lua = {
        enable = true;
        suggestion = {
          autoTrigger = true;
        };
      };
      mini = {
        enable = true;
        mockDevIcons = true;
        modules = {
          ai = {
            n_lines = 50;
            search_method = "cover_or_next";
          };
          comment = {
            mappings = {
              comment = "<leader>/";
              comment_line = "<leader>/";
              comment_visual = "<leader>/";
              textobject = "<leader>/";
            };
          };
          diff = {
            view = {
              style = "sign";
            };
          };
          starter = {
            content_hooks = {
              "__unkeyed-1.adding_bullet" = {
                __raw = "require('mini.starter').gen_hook.adding_bullet()";
              };
              "__unkeyed-2.indexing" = {
                __raw = "require('mini.starter').gen_hook.indexing('all', { 'Builtin actions' })";
              };
              "__unkeyed-3.padding" = {
                __raw = "require('mini.starter').gen_hook.aligning('center', 'center')";
              };
            };
            evaluate_single = true;
            header = ''
              ███╗   ██╗██╗██╗  ██╗██╗   ██╗██╗███╗   ███╗
              ████╗  ██║██║╚██╗██╔╝██║   ██║██║████╗ ████║
              ██╔██╗ ██║██║ ╚███╔╝ ██║   ██║██║██╔████╔██║
              ██║╚██╗██║██║ ██╔██╗ ╚██╗ ██╔╝██║██║╚██╔╝██║
              ██║ ╚████║██║██╔╝ ██╗ ╚████╔╝ ██║██║ ╚═╝ ██║
            '';
            items = {
              "__unkeyed-1.buildtin_actions" = {
                __raw = "require('mini.starter').sections.builtin_actions()";
              };
              "__unkeyed-2.recent_files_current_directory" = {
                __raw = "require('mini.starter').sections.recent_files(10, false)";
              };
              "__unkeyed-3.recent_files" = {
                __raw = "require('mini.starter').sections.recent_files(10, true)";
              };
              "__unkeyed-4.sessions" = {
                __raw = "require('mini.starter').sections.sessions(5, true)";
              };
            };
          };
          surround = {
            mappings = {
              add = "gsa";
              delete = "gsd";
              find = "gsf";
              find_left = "gsF";
              highlight = "gsh";
              replace = "gsr";
              update_n_lines = "gsn";
            };
          };
          move = { };
          icons = { };
          map = {
            integrations = {
              "__unkeyed-1.diagnostic_integration" = {
                __raw = ''
                  require("mini.map").gen_integration.diagnostic({
                      error = "DiagnosticFloatingError",
                      warn  = "DiagnosticFloatingWarn",
                      info  = "DiagnosticFloatingInfo",
                      hint  = "DiagnosticFloatingHint",
                  })
                '';
              };
              "__unkeyed-2.builtin_search" = {
                __raw = "require('mini.map').gen_integration.builtin_search()";
              };
              "__unkeyed-3.diff" = {
                __raw = "require('mini.map').gen_integration.diff()";
              };
            };
          };
        };
      };
      indent-blankline = {
        enable = true;
        settings = {
          indent = {
            char = "▏";
          };
          exclude = {
            filetypes = [
              "help"
              "terminal"
            ];
            buftypes = [ "terminal" ];
          };
        };
      };
      nvim-ufo = {
        enable = true;
        foldVirtTextHandler = ''
          function(virtText, lnum, endLnum, width, truncate)
                local newVirtText = {}
                local totalLines = vim.api.nvim_buf_line_count(0)
                local foldedLines = endLnum - lnum
                local suffix = ("  %d %d%%"):format(foldedLines, foldedLines / totalLines * 100)
                local sufWidth = vim.fn.strdisplaywidth(suffix)
                local targetWidth = width - sufWidth
                local curWidth = 0
                for _, chunk in ipairs(virtText) do
                  local chunkText = chunk[1]
                  local chunkWidth = vim.fn.strdisplaywidth(chunkText)
                  if targetWidth > curWidth + chunkWidth then
                    table.insert(newVirtText, chunk)
                  else
                    chunkText = truncate(chunkText, targetWidth - curWidth)
                    local hlGroup = chunk[2]
                    table.insert(newVirtText, { chunkText, hlGroup })
                    chunkWidth = vim.fn.strdisplaywidth(chunkText)
                    -- str width returned from truncate() may less than 2nd argument, need padding
                    if curWidth + chunkWidth < targetWidth then
                      suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
                    end
                    break
                  end
                  curWidth = curWidth + chunkWidth
                end
                local rAlignAppndx = math.max(math.min(vim.api.nvim_win_get_width(0), width - 1) - curWidth - sufWidth, 0)
                suffix = (" "):rep(rAlignAppndx) .. suffix
                table.insert(newVirtText, { suffix, "MoreMsg" })
                return newVirtText
              end
        '';
      };
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
