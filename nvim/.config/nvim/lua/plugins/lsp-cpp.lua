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
            "--clang-tidy-checks=*",
            "--completion-style=bundled",
            "--header-insertion=iwyu",
            "--header-insertion-decorations=none",
          },
          capabilities = {
            offsetEncoding = "utf-16",
          },
          -- Enable semantic highlighting
          semanticHighlighting = true,
          -- Diagnostics configuration
          on_attach = function(client, bufnr)
            -- Habilita diagnósticos
            vim.diagnostic.config({
              virtual_text = {
                prefix = "●",
                spacing = 4,
              },
              signs = true,
              underline = true,
              update_in_insert = true,
              severity_sort = true,
            })

            -- Ativa clang-tidy checks
            if client.server_capabilities.codeActionProvider then
              vim.keymap.set(
                "n",
                "<leader>ca",
                vim.lsp.buf.code_action,
                { noremap = true, silent = true, buffer = bufnr, desc = "Code Action" }
              )
            end
          end,
        },
      },
    },
  },

  {
    "nvimtools/none-ls.nvim",
    optional = true,
    opts = function(_, opts)
      local nls = require("null-ls")
      opts.sources = opts.sources or {}
      table.insert(opts.sources, nls.builtins.diagnostics.clang_check)
      table.insert(opts.sources, nls.builtins.formatting.clang_format)
    end,
  },

  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters_by_ft = {
        cpp = { "clang_tidy" },
        c = { "clang_tidy" },
      },
      linters = {
        clang_tidy = {
          cmd = "clang-tidy",
          stdin = false,
          args = {
            "--checks=*",
            "--header-filter=.*",
          },
          stream = "stderr",
          ignore_exitcode = true,
        },
      },
    },
  },
}
