{
  pkgs,
  pkgs-stable,
  ...
}:
let
  icons = import ./icons.nix;
in
{
  imports = [
    ./keymaps.nix
    ./plugins.nix
  ];
  home.packages = with pkgs; [
    gcc
    pkgs-stable.eslint
    mkcert
    nixfmt-rfc-style
    node2nix
    ruff
    goimports-reviser
    nodejs
    nodePackages.svelte-language-server
    npm-check-updates
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
      format-on-save

      workspace-diagnostics
      zenbones-nvim
      lush-nvim
    ];
    extraConfigLuaPre = ''
      vim.fn.sign_define("diagnosticsignerror", { text = " ", texthl = "diagnosticerror", linehl = "", numhl = "" })
      vim.fn.sign_define("diagnosticsignwarn", { text = " ", texthl = "diagnosticwarn", linehl = "", numhl = "" })
      vim.fn.sign_define("diagnosticsignhint", { text = "󰌵", texthl = "diagnostichint", linehl = "", numhl = "" })
      vim.fn.sign_define("diagnosticsigninfo", { text = " ", texthl = "diagnosticinfo", linehl = "", numhl = "" })
    '';
    extraConfigLuaPost = "vim.cmd [[ colorscheme kanagawabones ]]";
    # feature that enhances the way Neovim loads and executes Lua modules,
    # offering improved performance and flexibility.
    luaLoader.enable = true;

    clipboard.providers.wl-copy.enable = true;
    extraConfigLua = ''
        local format_on_save = require("format-on-save")
        local formatters = require("format-on-save.formatters")
        local vim_notify = require("format-on-save.error-notifiers.vim-notify")
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

  };
}
