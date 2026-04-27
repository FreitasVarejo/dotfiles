-- Project Files Support (.csproj, .sln, .xaml)
-- Adds syntax highlighting, treesitter support, and Mason tooling for project files

return {
  {
    "nvim-treesitter/nvim-treesitter",
    optional = true,
    opts = {
      ensure_installed = {
        "xml",
      },
    },
  },

  {
    "williamboman/mason.nvim",
    optional = true,
    opts = {
      ensure_installed = {
        -- XML language server for .csproj, .sln, .xaml
        "lemminx",
      },
    },
  },

  {
    "neovim/nvim-lspconfig",
    optional = true,
    opts = {
      servers = {
        lemminx = {
          -- Configure lemminx to handle .csproj, .sln, .xaml files
          filetypes = { "xml", "csproj", "sln", "xaml" },
          init_options = {
            extendedClientCapabilities = {
              actionableNotificationSupport = true,
            },
          },
        },
      },
    },
  },

  {
    "LazyVim/LazyVim",
    optional = true,
    cond = function()
      -- Register custom filetypes for project files
      vim.filetype.add({
        extension = {
          csproj = "xml",
          sln = "dotsln",
          xaml = "xml",
        },
        pattern = {
          [".*/%.csproj"] = "xml",
          [".*/%.sln"] = "dotsln",
          [".*/%.xaml"] = "xml",
        },
      })
      return false
    end,
  },
}
