return {
  -- Colorscheme
  {
    "folke/tokyonight.nvim",
    lazy = true,
    priority = 1000,
    opts = function()
      return {
        transparent = false,
      }
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight",
    },
  },

  -- Disable built-in netrw so yazi owns directory listings.
  -- Setting it here is sufficient for yazi-triggered opens; for
  -- initial directory buffers, also handled by LazyVim by default.
  {
    "mikavilpas/yazi.nvim",
    event = "VeryLazy",
    config = function()
      vim.g.loaded_netrwPlugin = 1
      vim.api.nvim_create_user_command("Yazi", function(opts)
        if opts.args and opts.args ~= "" then
          require("yazi").yazi(nil, opts.args)
        else
          require("yazi").yazi()
        end
      end, { nargs = "?", desc = "Open yazi" })
      vim.api.nvim_create_user_command("YaziCwd", function()
        require("yazi").yazi(nil, vim.fn.getcwd())
      end, { desc = "Open yazi at current working directory" })
      vim.api.nvim_create_user_command("YaziToggle", function()
        require("yazi").toggle()
      end, { desc = "Toggle yazi" })
    end,
    keys = {
      {
        "<leader>-",
        function()
          require("yazi").yazi()
        end,
        desc = "Open yazi at the current file",
      },
      {
        "<leader>cw",
        function()
          require("yazi").yazi(nil, vim.fn.getcwd())
        end,
        desc = "Open yazi at the current working directory",
      },
      {
        "<leader>y",
        function()
          require("yazi").toggle()
        end,
        desc = "Toggle the last yazi session",
      },
    },
    opts = {
      open_for_directories = true,
      change_neovim_cwd_on_close = true,
      keymaps = {
        show_help = "<f1>",
      },
    },
  },

  {
    "folke/snacks.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      picker = { enabled = true },
      input = { enabled = true },
      image = { enabled = false },
      dashboard = {
        preset = {
          header = [[
 ██████╗ ████████╗ ██████╗     ██████╗  █████╗  ██████╗████████╗██╗   ██╗ █████╗ ██╗
 ██╔══██╗╚══██╔══╝██╔════╝     ██╔══██╗██╔══██╗██╔════╝╚══██╔══╝██║   ██║██╔══██╗██║
 ██████╔╝   ██║   ██║  ███╗    ██████╔╝███████║██║        ██║   ██║   ██║███████║██║
 ██╔══██╗   ██║   ██║   ██║    ██╔═══╝ ██╔══██║██║        ██║   ██║   ██║██╔══██║██║
     ██████╔╝   ██║   ╚██████╔╝    ██║     ██║  ██║╚██████╗   ██║   ╚██████╔╝██║  ██║███████╗
     ╚═════╝    ╚═╝    ╚═════╝     ╚═╝     ╚═╝  ╚═╝ ╚═════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝
          ]],
        },
      },
    },
  },

  -- Browser preview of markdown is not used; render in-buffer instead.
  {
    "iamcco/markdown-preview.nvim",
    enabled = false,
  },
}
