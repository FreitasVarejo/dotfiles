return {
  -- Pasta aberta na linha de comando fica com o explorer do Snacks; o yazi é
  -- só por tecla ou :Yazi (que o próprio plugin registra, com cwd/toggle/logs).
  {
    "mikavilpas/yazi.nvim",
    event = "VeryLazy",
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
  },

  {
    "mason-org/mason.nvim",
    opts = {
      ui = {
        border = "rounded",
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    },
  },

  {
    "folke/snacks.nvim",
    opts = {
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
