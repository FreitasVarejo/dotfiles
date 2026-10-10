return {
  -- Formatting with shfmt for shell scripts
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        bash = { "shfmt" },
        sh = { "shfmt" },
      },
    },
  },

  -- LSP Configuration for Bash Language Server
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        bashls = {
          filetypes = { "sh", "bash" },
          settings = {
            bashIde = {
              globPattern = vim.env.GLOB_PATTERN or "*@(.sh|.bash)",
              includeAllWorkspaceSymbols = false,
              explainshellEndpoint = "",
            },
          },
        },
      },
    },
  },
}
