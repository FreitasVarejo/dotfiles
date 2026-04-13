return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        eslint = {},
        typescript_tools = {
          settings = {
            tsserver = {
              autoUseWorkspaceTsdk = true,
              useSeparateSyntaxServer = false,
            },
          },
        },
      },
    },
  },
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        -- Core
        "stylua",
        "shfmt",
        -- Web dev
        "typescript-language-server",
        "eslint_d",
        "prettier",
        "tailwindcss-language-server",
        "html-lsp",
        "css-lsp",
        "json-lsp",
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "javascript",
        "typescript",
        "tsx",
        "jsx",
        "css",
        "html",
        "json",
        "yaml",
        "markdown",
      },
    },
  },
}
