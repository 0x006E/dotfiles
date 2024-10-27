{
  pkgs,
  pkgs-unstable,
  inputs,
  ...
}:

let
  format-on-save = pkgs.vimUtils.buildVimPlugin {
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
  };

  tailwindcss-colorizer-cmp = pkgs.vimUtils.buildVimPlugin {
    name = "tailwindcss-colorizer-cmp";
    src = pkgs.fetchFromGitHub {
      owner = "roobert";
      repo = "tailwindcss-colorizer-cmp.nvim";
      rev = "3d3cd95e4a4135c250faf83dd5ed61b8e5502b86";
      hash = "sha256-PIkfJzLt001TojAnE/rdRhgVEwSvCvUJm/vNPLSWjpY=";
    };
  };

  workspace-diagnostics = pkgs.vimUtils.buildVimPlugin {
    name = "workspace-diagnostics.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "artemave";
      repo = "workspace-diagnostics.nvim";
      rev = "573ff93c47898967efdfbc6587a1a39e3c2d365e";
      hash = "sha256-lBj4KUPmmhtpffYky/HpaTwY++d/Q9socp/Ys+4VeX0=";
    };
  };

  magazine = pkgs.vimPlugins.nvim-cmp.overrideAttrs (old: {
    src = pkgs.fetchFromGitHub {
      owner = "iguanacucumber";
      repo = "magazine.nvim";
      rev = "4aec249cdcef9b269e962bf73ef976181ee7fdd9";
      hash = "sha256-qobf9Oyt9Voa2YUeZT8Db7O8ztbGddQyPh5wIMpK/w8=";
    };
  });
  tiny-inline-diagnostic = pkgs.vimUtils.buildVimPlugin {
    name = "tiny-inline-diagnostic";
    src = pkgs.fetchFromGitHub {
      owner = "rachartier";
      repo = "tiny-inline-diagnostic.nvim";
      rev = "a4f8b29eb318b507a5e5c11e6d69bea4f5bc2ab2";
      hash = "sha256-S+O5hI0hF3drTwTwIlQ3aPl9lTBErt53lgUFlQGSCA8=";
    };
  };
in

{

  home.packages = with pkgs; [
    gcc
    hugo
    eslint_d
    eslint
    mkcert
    nixfmt-rfc-style
    node2nix
    goimports-reviser
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
    vimAlias = false;
    extraPlugins = with pkgs.vimPlugins; [
      tailwindcss-colors-nvim
      tailwindcss-colorizer-cmp
      tiny-inline-diagnostic
      format-on-save
      workspace-diagnostics
    ];
    extraConfigLua = ''
      local format_on_save = require("format-on-save")
      local formatters = require("format-on-save.formatters")
      local vim_notify = require("format-on-save.error-notifiers.vim-notify")
      require("tailwindcss-colorizer-cmp").setup({})
      require('tiny-inline-diagnostic').setup()
      format_on_save.setup({

        experiments = {
           partial_update = 'diff', -- or 'line-by-line'
        },
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
          -- formatters.prettierd,
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
        enable = true;
        # pathsToLink = [
        #   ""
        # ];
        standalonePlugins = [
          "nvim-treesitter"
          "copilot.lua"
          "smart-splits.nvim"
        ];
      };
    };
    package = pkgs-unstable.neovim-unwrapped;

    autoGroups = {
      remember_folds = {
        clear = true;
      };
    };
    autoCmd = [
      {
        event = [ "VimEnter" ];
        pattern = [ "*" ];
        callback = {
          __raw = "MiniMap.open";
        };
      }
      {
        event = "BufWinLeave";
        pattern = "*.*";
        command = "mkview";
        group = "remember_folds";
      }
      {
        event = "BufWinEnter";
        pattern = "*.*";
        command = "silent! loadview";
        group = "remember_folds";
      }
    ];
    globals.mapleader = " ";
    colorschemes.ayu = {
      enable = true;
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
      fillchars = "eob: ,fold: ,foldopen:,foldsep:|,foldclose:";
    };
    keymaps = [
      {
        key = "<leader>ss";
        action = "<cmd>Spectre<cr>";
        mode = [ "n" ];
      }
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
        action = ":Bdelete<cr>";
        mode = [
          "n"
          "v"
        ];
      }
      {
        key = ",,";
        action = "<C-\\><C-n>";
        mode = [ "t" ];
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
          __raw = ''
            function()
              local MiniFiles = require("mini.files")
              local _ = MiniFiles.close() or MiniFiles.open(vim.api.nvim_buf_get_name(0), false)
              vim.defer_fn(function()
                MiniFiles.reveal_cwd()
              end, 30)
            end
          '';
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
      # Resizing splits
      {
        key = "<A-h>";
        action.__raw = "require('smart-splits').resize_left";
        mode = "n";
      }
      {
        key = "<A-j>";
        action.__raw = "require('smart-splits').resize_down";
        mode = "n";
      }
      {
        key = "<A-k>";
        action.__raw = "require('smart-splits').resize_up";
        mode = "n";
      }
      {
        key = "<A-l>";
        action.__raw = "require('smart-splits').resize_right";
        mode = "n";
      }
      # Moving between splits
      {
        key = "<C-h>";
        action.__raw = "require('smart-splits').move_cursor_left";
        mode = "n";
      }
      {
        key = "<C-j>";
        action.__raw = "require('smart-splits').move_cursor_down";
        mode = "n";
      }
      {
        key = "<C-k>";
        action.__raw = "require('smart-splits').move_cursor_up";
        mode = "n";
      }
      {
        key = "<C-l>";
        action.__raw = "require('smart-splits').move_cursor_right";
        mode = "n";
      }
      {
        key = "<C-\\>";
        action.__raw = "require('smart-splits').move_cursor_previous";
        mode = "n";
      }
      # Swapping buffers between windows
      {
        key = "<leader><leader>h";
        action.__raw = "require('smart-splits').swap_buf_left";
        mode = "n";
      }
      {
        key = "<leader><leader>j";
        action.__raw = "require('smart-splits').swap_buf_down";
        mode = "n";
      }
      {
        key = "<leader><leader>k";
        action.__raw = "require('smart-splits').swap_buf_up";
        mode = "n";
      }
      {
        key = "<leader><leader>l";
        action.__raw = "require('smart-splits').swap_buf_right";
        mode = "n";
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

      # trouble
      {
        key = "<leader>xx";
        action = "<cmd>Trouble diagnostics toggle<cr>";
        options = {
          silent = true;
          desc = "Diagnostics (Trouble)";
        };
      }
      {
        key = "<leader>xX";
        action = "<cmd>Trouble diagnostics toggle filter.buf=0<cr>";
        options = {
          silent = true;
          desc = "Buffer Diagnostics (Trouble)";
        };
      }
      {
        key = "<leader>cs";
        action = "<cmd>Trouble symbols toggle focus=false<cr>";
        options = {
          silent = true;
          desc = "Symbols (Trouble)";
        };
      }
      {
        key = "<leader>cl";
        action = "<cmd>Trouble lsp toggle focus=false win.position=right<cr>";
        options = {
          silent = true;
          desc = "LSP Definitions / references / ... (Trouble)";
        };
      }
      {
        key = "<leader>xL";
        action = "<cmd>Trouble loclist toggle<cr>";
        options = {
          silent = true;
          desc = "Location List (Trouble)";
        };
      }
      {
        key = "<leader>xQ";
        action = "<cmd>Trouble qflist toggle<cr>";
        options = {
          silent = true;
          desc = "Quickfix List (Trouble)";
        };
      }
    ];

    plugins = {
      bufdelete.enable = true;
      noice.enable = true;
      hardtime.enable = true;
      notify.enable = true;
      trouble = {
        enable = true;
        settings = {
          preview = {
            scratch = false;
          };
          open_no_results = true;
          auto_preview = false;
        };
      };
      # efmls-configs.enable = true;
      leap.enable = true;
      ts-comments.enable = true;
      friendly-snippets.enable = true;
      which-key.enable = true;
      sleuth.enable = true;
      nix.enable = true;
      project-nvim.enable = true;
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

      smart-splits.enable = true;

      # neoterm.enable = true;
      floaterm = {
        enable = true;
        keymaps = {
          toggle = ",tt";
          new = ",tN";
          kill = ",tk";
          next = ",tn";
          prev = ",tp";
        };
        wintype = "split";
        height = 0.3;
      };
      copilot-lua = {
        enable = true;
        suggestion = {
          autoTrigger = true;
          keymap = {
            accept = "<C-Enter>";
          };
        };
      };
      airline = {
        enable = true;
        settings = {
          powerline_fonts = 1;
        };
      };
      autoclose.enable = true;
      mini = {
        enable = true;
        mockDevIcons = true;
        modules = {
          notify = { };
          ai = {
            n_lines = 50;
            search_method = "cover_or_next";
          };
          animate = { };
          tabline = { };
          sessions = {
            autoread = true;
          };
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
            window = {
              winblend = 95;
            };
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
        settings = {
          fold_virt_text_handler = {
            __raw = ''
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
        };
      };
      precognition.enable = true;
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
        extensions = {
          ui-select.enable = true;
        };
        keymaps = {
          "<leader>ff" = "find_files";
          "<leader>fg" = "live_grep";
          "<leader>fb" = "buffers";
        };
      };

      lsp = {
        enable = true;
        capabilities = ''
          capabilities.textDocument.foldingRange = {
           dynamicRegistration = false,
           lineFoldingOnly = true
          }
        '';
        inlayHints = true;
        onAttach = "require('workspace-diagnostics').populate_workspace_diagnostics(client, bufnr)";
        servers = {
          templ.enable = true;
          vtsls = {
            enable = true;
            package = pkgs.vtsls;
            extraOptions = {
              commands = {
                OrganizeImports = {
                  __raw = ''
                    {
                      function()
                        local params = {
                          command = "_typescript.organizeImports",
                          arguments = {vim.api.nvim_buf_get_name(0)},
                          title = ""
                        }
                        vim.lsp.buf.execute_command(params)
                      end,
                      description = "Organize Imports"
                    }
                  '';
                };
              };
            };
          };

          htmx = {
            enable = true;
            filetypes = [
              "html"
              "templ"
            ];
          };
          html = {
            enable = true;
            filetypes = [
              "html"
              "templ"
            ];
          };
          cssls.enable = true;
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
          tailwindcss = {
            enable = true;
            filetypes = [
              "html"
              "javascript"
              "typescript"
              "react"
              "templ"
            ];
            onAttach.function = ''
              require('tailwindcss-colors').buf_attach(bufnr)
            '';
            settings = {
              tailwindCSS = {
                includeLanguages = {
                  templ = "html";
                };
              };
            };
          };
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
              };

            };
            extraOptions = {
              offset_encoding = "utf-8";
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
            gr = "rename";
            "<C-Space>" = "code_action";
          };
          diagnostic = {
            "<leader>j" = "goto_next";
            "<leader>k" = "goto_prev";
          };
        };
      };

      cmp = {
        enable = true;
        package = magazine;
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
          formatting = {
            format = ''
              function (entry, vim_item) 
                return require("tailwindcss-colorizer-cmp").formatter(entry, vim_item)
              end
            '';
          };
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
