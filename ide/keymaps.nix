{ ... }:
{
  programs.nixvim.keymaps = [
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

}
