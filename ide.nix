{
  pkgs,
  pkgs-unstable,
  ...
}:

let
  icons = {
    diagnostics = {
      BoldError = " ";
      Error = " ";
      BoldWarning = " ";
      Warning = " ";
      BoldInformation = " ";
      Information = " ";
      BoldQuestion = " ";
      Question = " ";
      BoldHint = " ";
      Hint = " ";
      Debug = " ";
      Trace = "✎ ";
    };

    git = {
      LineAdded = " ";
      LineModified = " ";
      LineRemoved = " ";
      FileDeleted = " ";
      FileIgnored = "◌ ";
      FileRenamed = " ";
      FileStaged = "✓ ";
      FileUnmerged = " ";
      FileUnstaged = " ";
      FileUntracked = "★ ";
      Diff = " ";
      Repo = " ";
      Octoface = " ";
      Branch = " ";
    };

    ui = {
      Time = " ";
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
      signup-nvim
      tailwindcss-colors-nvim
      tailwindcss-colorizer-cmp
      tiny-inline-diagnostic
      format-on-save
      workspace-diagnostics
      remote-nvim
    ];
    extraConfigLuaPre = ''
      vim.fn.sign_define("diagnosticsignerror", { text = " ", texthl = "diagnosticerror", linehl = "", numhl = "" })
      vim.fn.sign_define("diagnosticsignwarn", { text = " ", texthl = "diagnosticwarn", linehl = "", numhl = "" })
      vim.fn.sign_define("diagnosticsignhint", { text = "󰌵", texthl = "diagnostichint", linehl = "", numhl = "" })
      vim.fn.sign_define("diagnosticsigninfo", { text = " ", texthl = "diagnosticinfo", linehl = "", numhl = "" })
    '';

    # feature that enhances the way Neovim loads and executes Lua modules,
    # offering improved performance and flexibility.
    luaLoader.enable = true;

    clipboard.providers.wl-copy.enable = true;
    extraConfigLua = ''
        local format_on_save = require("format-on-save")
        local formatters = require("format-on-save.formatters")
        local vim_notify = require("format-on-save.error-notifiers.vim-notify")
        require("tailwindcss-colorizer-cmp").setup({})
        require('tiny-inline-diagnostic').setup({})
        require("signup").setup(
        {
            win = nil,
            buf = nil,
            timer = nil,
            visible = false,
            current_signatures = nil,
            enabled = false,
            normal_mode_active = false,
            config = {
              silent = false,
              number = true,
              icons = {
                parameter = " ",
                method = " ",
                documentation = " ",
              },
              colors = {
                parameter = "#86e1fc",
                method = "#c099ff",
                documentation = "#4fd6be",
              },
              active_parameter_colors = {
                bg = "#86e1fc",
                fg = "#1a1a1a",
              },
              border = "solid",
              winblend = 10,
            }
        })
        require('remote-nvim').setup({
          devpod = {
            gpg_agent_forwarding = true,
          }
        })

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
        local ui = {}

        function ui.fg(name)
          local hl = vim.api.nvim_get_hl and vim.api.nvim_get_hl(0, { name = name }) or vim.api.nvim_get_hl_by_name(name, true)
          local fg = hl and (hl.fg or hl.foreground)
          return fg and { fg = string.format("#%06x", fg) } or nil
        end

        ---@param opts? {relative: "cwd"|"root", modified_hl: string?}
        function ui.pretty_path(opts)
          opts = vim.tbl_extend("force", {
            relative = "cwd",
            modified_hl = "Constant",
          }, opts or {})

          return function(self)
            local path = vim.fn.expand("%:p") --[[@as string]]

            if path == "" then
              return ""
            end

            local bufname = vim.fn.bufname(vim.fn.bufnr())
            local sep = package.config:sub(1, 1)
            
            local root = (opts.relative == "root") and vim.fn.getcwd() or vim.fn.fnamemodify(bufname, ":h")
            local cwd = vim.fn.getcwd()

            path = (opts.relative == "cwd" and path:find(cwd, 1, true) == 1) and path:sub(#cwd + 2) or path:sub(#root + 2)

            local parts = vim.split(path, "[\\/]")
            if #parts > 3 then
              parts = { parts[1], "…", parts[#parts - 1], parts[#parts] }
            end

            if opts.modified_hl and vim.bo.modified then
              local modified_hl_fg = ui.fg(opts.modified_hl)
              if modified_hl_fg then
                parts[#parts] = string.format("%%#%s#%s%%*", opts.modified_hl, parts[#parts])
              end
            end

            return table.concat(parts, sep)
          end
        end

        require("lualine").setup({
            sections = {
              lualine_c = {
                  {
                    "diagnostics",
                    symbols = {
                      error = "${icons.diagnostics.Error}",
                      warn  = "${icons.diagnostics.Warning}",
                      hint  = "${icons.diagnostics.Hint}",
                      info  = "${icons.diagnostics.BoldInformation}",
                    },
                  },
                  { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
                  { ui.pretty_path() },
                },
              lualine_x = {
            {
              function() return require("noice").api.status.command.get() end,
              cond = function() return package.loaded["noice"] and require("noice").api.status.command.has() end,
              color = ui.fg("Statement"),
            },
            {
              function() return require("noice").api.status.mode.get() end,
              cond = function() return package.loaded["noice"] and require("noice").api.status.mode.has() end,
              color = ui.fg("Constant"),
            },
            {
              function() return "${icons.diagnostics.Debug}" .. require("dap").status() end,
              cond = function () return package.loaded["dap"] and require("dap").status() ~= "" end,
              color = ui.fg("Debug"),
            },
            {
            "diff",
            symbols = {
              added = "${icons.git.LineAdded}",
              modified = "${icons.git.LineModified}",
              removed= "${icons.git.LineRemoved}",
              },
            },
          }
        }
      })
    '';
    performance = {
      byteCompileLua = {
        enable = false;
        nvimRuntime = true;
        plugins = true;
      };
      combinePlugins = {
        enable = false;
        standalonePlugins = [
          "nvim-cmp"
          "smart-splits.nvim"
        ];
        pathsToLink = [
          "/scripts"
        ];
      };

    };

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
      foldcolumn = "1";
      foldlevel = 99;
      foldlevelstart = 99;
      # fillchars = "eob: ,fold: ,foldopen:,foldsep:|,foldclose:";
      ignorecase = true;
      smartcase = true; # Don't ignore case with capitals
      grepprg = "rg --vimgrep";
      grepformat = "%f:%l:%c:%m";

      # Better colors
      termguicolors = true;
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
      statuscol = {
        enable = true;
        settings = {
          relculright = true;
          segments = [
            { text = [ "%s" ]; }
            {
              text = [
                {
                  __raw = "require('statuscol.builtin').lnumfunc";
                }
              ];
            }
            {
              text = [
                " "
                {
                  __raw = "require('statuscol.builtin').foldfunc";
                }
                "  "
              ];
              condition = [
                {
                  __raw = "require('statuscol.builtin').not_empty";
                }
                true
                {
                  __raw = "require('statuscol.builtin').not_empty";
                }
              ];
            }
          ];
        };
      };
      smartcolumn.enable = true;
      nui.enable = true;
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
      lualine = {
        enable = true;
        settings = {
          options = {
            always_divide_middle = true;
            ignore_focus = [ "neo-tree" ];
            globalstatus = true; # have a single statusline at bottom of neovim instead of one for every window
            disabled_filetypes.statusline = [
              "dashboard"
              "alpha"
            ];
            section_separators = {
              left = "";
              right = "";
            };
          };
          extensions = [ "fzf" ];
          sections = {
            lualine_a = [ "mode" ];
            lualine_b = [ "branch" ];
            lualine_y = [
              "progress"
              {
                separator = "";
              }
              "location"
              {
                padding = {
                  left = 0;
                  right = 1;
                };
              }
            ];
            lualine_z = [ ''"${icons.ui.Time}" .. os.date("%R")'' ];
          };
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

      auto-session.enable = true;
      telescope = {
        enable = true;
        extensions = {
          ui-select.enable = true;
          frecency.enable = true;
          fzf-native.enable = true;
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
                          command = "typescript.organizeImports",
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
            package = pkgs-unstable.nixd;
            settings = {
              nixpkgs = {
                expr = "import <nixpkgs> { }";
              };
              formatting = {
                command = [ "nix" "fmt" ];
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
      luasnip = {
        enable = true;
        settings = {
          enable_autosnippets = true;
          store_selection_keys = "<Tab>";
        };
        fromVscode = [
          {
            lazyLoad = true;
            paths = "${pkgs.vimPlugins.friendly-snippets}";
          }
        ];
      };
      cmp-nvim-lsp.enable = true;
      cmp-emoji.enable = true;
      cmp-buffer.enable = true;
      cmp-path.enable = true;
      cmp_luasnip.enable = true;
      cmp-cmdline.enable = true;
      cmp = {
        enable = true;
        package = pkgs.magazine;
        autoEnableSources = true;
        cmdline = {
          "/" = {
            mapping.__raw = "cmp.mapping.preset.cmdline()";
            sources = [ { name = "buffer"; } ];
          };
          ":" = {
            mapping.__raw = "cmp.mapping.preset.cmdline()";
            sources = [
              { name = "path"; }
              {
                name = "cmdline";
                option.ignore_cmds = [
                  "Man"
                  "!"
                ];
              }
            ];
          };
        };

        filetype = {
          sql.sources = [
            { name = "buffer"; }
            { name = "vim-dadbod-completion"; }
          ];
        };
        settings = {
          formatting = {
            format = ''
              function (entry, vim_item) 
                return require("tailwindcss-colorizer-cmp").formatter(entry, vim_item)
              end
            '';
          };
          completion.completeopt = "menu,menuone,noinsert";
          sources = [
            { name = "nvim_lsp"; } # lsp
            { name = "luasnip"; }
            # { name = "copilot"; }
            {
              name = "buffer";
              # Words from other open buffers can also be suggested.
              option.get_bufnrs.__raw = "vim.api.nvim_list_bufs";
              keywordLength = 3;
            }
            { name = "path"; }
          ];

          window = {
            completion.border = "rounded";
            documentation.border = "rounded";
          };
          experimental.ghost_text = true;

          mapping = {
            "<Tab>".__raw = ''
              cmp.mapping(function(fallback)
                local luasnip = require("luasnip")
                if cmp.visible() then
                  cmp.select_next_item()
                elseif luasnip.locally_jumpable(1) then
                  luasnip.jump(1)
                else
                  fallback()
                end
              end, { "i", "s" })
            '';

            "<S-Tab>".__raw = ''
              cmp.mapping(function(fallback)
                local luasnip = require("luasnip")
                if cmp.visible() then
                  cmp.select_prev_item()
                elseif luasnip.locally_jumpable(-1) then
                  luasnip.jump(-1)
                else
                  fallback()
                end
              end, { "i", "s" })
            '';
            "<CR>".__raw = ''
              cmp.mapping(function(fallback)
                local luasnip = require("luasnip")
                if cmp.visible() then
                  if luasnip.expandable() then
                    luasnip.expand()
                  else
                    cmp.confirm({
                      select = true,
                    })
                  end
                else
                  fallback()
                end
              end)
            '';
            "<c-n>" = "cmp.mapping(cmp.mapping.select_next_item())";
            "<c-p>" = "cmp.mapping(cmp.mapping.select_prev_item())";
            "<c-e>" = "cmp.mapping.abort()";
            "<C-d>" = "cmp.mapping.scroll_docs(-4)";
            "<C-f>" = "cmp.mapping.scroll_docs(4)";
            "<Up>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
            "<Down>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
            "<C-Space>" = "cmp.mapping.complete()";
          };

          snippet.expand.__raw = ''
            function(args)
              require('luasnip').lsp_expand(args.body)
            end
          '';

        };
      };
    };
  };
}
