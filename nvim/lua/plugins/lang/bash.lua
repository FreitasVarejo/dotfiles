return {
  -- TreeSitter support for shell languages
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "bash",        -- Bash scripting language
        "fish",        -- Fish shell
        "git_config",  -- Git configuration files
      },
    },
  },

  -- Formatting with shfmt for shell scripts
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        bash = { "shfmt" },
        sh = { "shfmt" },
      },
      format_on_save = {
        timeout_ms = 3000,
        lsp_fallback = true,
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
