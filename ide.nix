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
    lazygit
    prettierd
    pyright
    (sqlite.override { interactive = true; })
    xh
    ripgrep
  ];
  programs.nixvim = {
    enable = true;
    vimAlias = true;
    extraPlugins = [
      (pkgs.vimUtils.buildVimPlugin {
        name = "format-on-save";
        src = pkgs.fetchFromGitHub {
          owner = "elentok";
          repo = "format-on-save.nvim";
          rev = "fed870bb08d9889580f5ca335649da2074bd4b6f";
          hash = "sha256-07RWMrBDVIH3iGgo2RcNDhThSrR/Icijcd//MOnBzpA=";
        };
        patches = [
          (pkgs.fetchpatch {
            url = "https://github.com/elentok/format-on-save.nvim/pull/24.patch";
            hash = "sha256-g1SSjxCaoP/AAUBkOY1ZSVI9wuDl5o5Sie8YzZt6zgQ=";
          })

        ];
      })
    ];
    extraConfigLua = ''
      local format_on_save = require("format-on-save")
      local formatters = require("format-on-save.formatters")
      local vim_notify = require("format-on-save.error-notifiers.vim-notify")
      format_on_save.setup({
        error_notifier = vim_notify,
        exclude_path_patterns = {
          "/node_modules/",
        },
        formatter_by_ft = {
          css = formatters.lsp,
          html = formatters.lsp,
          java = formatters.lsp,
          javascript = formatters.lsp,
          json = formatters.lsp,
          lua = formatters.lsp,
          markdown = formatters.prettierd,
          openscad = formatters.lsp,
          python = formatters.black,
          rust = formatters.lsp,
          scad = formatters.lsp,
          scss = formatters.lsp,
          sh = formatters.shfmt,
          terraform = formatters.lsp,
          typescript = formatters.prettierd,
          typescriptreact = formatters.prettierd,
          yaml = formatters.lsp,
          nix = formatters.lsp,
          -- Concatenate formatters
          python = {
            formatters.remove_trailing_whitespace,
            formatters.shell({ cmd = "tidy-imports" }),
            formatters.black,
            formatters.ruff,
          },

          -- Use a tempfile instead of stdin
          go = {
            formatters.shell({
              cmd = { "goimports-reviser", "-rm-unused", "-set-alias", "-format", "%" },
              tempfile = function()
                return vim.fn.expand("%") .. '.formatter-temp'
              end
            }),
            formatters.shell({ cmd = { "gofmt" } }),
          },

          -- Add conditional formatter that only runs if a certain file exists
          -- in one of the parent directories.
          javascript = {
            formatters.if_file_exists({
              pattern = ".eslintrc.*",
              formatter = formatters.eslint_d_fix
            }),
            formatters.if_file_exists({
              pattern = { ".prettierrc", ".prettierrc.*", "prettier.config.*" },
              formatter = formatters.prettierd,
            }),
          },
        },

        -- Optional: fallback formatter to use when no formatters match the current filetype
        fallback_formatter = {
          formatters.lsp,
          formatters.remove_trailing_whitespace,
          formatters.remove_trailing_newlines,
          formatters.prettierd,
        },

        -- By default, all shell commands are prefixed with "sh -c" (see PR #3)
        -- To prevent that set `run_with_sh` to `false`.
        -- run_with_sh = false,
      })
    '';
    performance = {
      byteCompileLua = {
        enable = true;
        nvimRuntime = true;
        plugins = true;
      };
      combinePlugins = {
        enable = false;
        # standalonePlugins = [
        #   "nvim-treesitter"
        #   "copilot-lua"
        # ];
      };
    };
    package = pkgs-unstable.neovim-unwrapped;
    autoCmd = [
      # {
      #   event = [ "BufWritePre" ];
      #   pattern = [ "*" ];
      #   command = "lua vim.lsp.buf.format()";
      #
      # }

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
      tabstop = 2;
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
        key = "<leader>lg";
        action = "<cmd>LazyGit<cr>";
        mode = [ "n" ];
      }
      {
        key = "<leader>d";
        action = "\"_d";
        mode = [
          "n"
          "x"
        ];
      }
      {
        key = "<leader>n";
        action = ":bnext<cr>";
        mode = [
          "n"
          "v"
        ];
      }
      {
        key = "<leader>p";
        action = ":bprevious<cr>";
        mode = [
          "n"
          "v"
        ];
      }
      {
        key = "<leader>d";
        action = ":bdelete<cr>";
        mode = [
          "n"
          "v"
        ];
      }
      {
        key = "jj";
        action = "<esc>";
        mode = [ "i" ];
      }

      {
        key = "<leader>u";
        action = "<cmd>UndotreeToggle<cr>";
        mode = [
          "n"
          "v"
        ];
      }
      {
        key = "<leader>o";
        action = {
          __raw = "function () if not MiniFiles.close() then MiniFiles.open() end end";
        };
        mode = [
          "n"
          "v"
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
      nix.enable = true;
      project-nvim.enable = true;
      lualine.enable = true;
      nvim-colorizer.enable = true;
      lazygit.enable = true;
      direnv.enable = true;
      spectre = {
        enable = true;
        findPackage = pkgs.ripgrep;
        replacePackage = pkgs.gnused;
      };
      emmet.enable = true;
      undotree = {
        enable = true;
        settings = {
          CursorLine = true;
          DiffAutoOpen = true;
          DiffCommand = "diff";
          DiffpanelHeight = 10;
          HelpLine = true;
          HighlightChangedText = true;
          HighlightChangedWithSign = true;
          HighlightSyntaxAdd = "DiffAdd";
          HighlightSyntaxChange = "DiffChange";
          HighlightSyntaxDel = "DiffDelete";
          RelativeTimestamp = true;
          SetFocusWhenToggle = true;
          ShortIndicators = false;
          SplitWidth = 40;
          TreeNodeShape = "*";
          TreeReturnShape = "\\";
          TreeSplitShape = "/";
          TreeVertShape = "|";
          WindowLayout = 4;
        };
      };
      # neoterm.enable = true;
      floaterm = {
        enable = true;
        keymaps = {
          toggle = "<leader>tt";
          new = "<leader>tN";
          kill = "<leader>tk";
          next = "<leader>tn";
          prev = "<leader>tp";
        };
        wintype = "split";
        height = 0.3;
      };
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
          notify = { };
          ai = {
            n_lines = 50;
            search_method = "cover_or_next";
          };
          tabline = { };
          sessions = { };
          files = { };
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
          eslint = {
            enable = true;
            autostart = true;
            settings = {
              codeActionOnSave = {
                enable = true;
                mode = "all";
              };
            };
          };
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
