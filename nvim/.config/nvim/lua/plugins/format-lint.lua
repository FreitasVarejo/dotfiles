-- Formatting and Linting Configuration
-- Registers formatters for various filetypes with format_on_save enabled

return {
  {
    "conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        cs = { "csharpier" },
      },
      format_on_save = {
        timeout_ms = 500,
        lsp_fallback = true,
      },
    },
  },

  {
    "neovim/nvim-lspconfig",
    optional = true,
    opts = {
      servers = {
        -- XML/CSPROJ support via lemminx
        lemminx = {
          filetypes = { "xml", "csproj", "sln", "xaml" },
        },
      },
    },
  },

  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters_by_ft = {
        -- Project files are validated by LSP
        csproj = {},
        sln = {},
        xaml = {},
      },
    },
  },
}
