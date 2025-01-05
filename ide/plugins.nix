{ pkgs, pkgs-unstable, ... }:
let
  icons = import ./icons.nix;
in
{
  programs.nixvim.plugins = {
    remote-nvim = {
      enable = true;
      package = pkgs.vimPlugins.remote-nvim-nvim.overrideAttrs (oldAttrs: {
        dontPatchShebangs = true;
      });
      settings = {
        devpod = {
          gpg_agent_forwarding = true;
        };
      };
    };

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
    colorizer.enable = true;
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
      settings = {
        keymap_toggle = ",tt";
        keymap_new = ",tN";
        keymap_kill = ",tk";
        keymap_next = ",tn";
        keymap_prev = ",tp";
        wintype = "split";
        height = 0.3;
      };
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
              command = [
                "nix"
                "fmt"
                "--"
                "--"
              ];
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
}
