-- C++ LSP Configuration
-- Configura clangd e clang-tidy para diagnósticos em tempo real

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        clangd = {
          cmd = {
            "clangd",
            "--offset-encoding=utf-16",
            "--background-index",
            "--clang-tidy",
            "--clang-tidy-checks=readability-*,modernize-*",
            "--completion-style=bundled",
            "--header-insertion=iwyu",
            "--header-insertion-decorations=none",
          },
          capabilities = {
            offsetEncoding = "utf-16",
          },
        },
      },
    },
  },

  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters_by_ft = {
        cpp = { "clangtidy" },
        c = { "clangtidy" },
        cc = { "clangtidy" },
        cxx = { "clangtidy" },
      },
    },
  },

  {
    "nvimtools/none-ls.nvim",
    optional = true,
    opts = function(_, opts)
      local nls = require("null-ls")
      opts.sources = opts.sources or {}
      table.insert(opts.sources, nls.builtins.formatting.clang_format)
    end,
  },
}
