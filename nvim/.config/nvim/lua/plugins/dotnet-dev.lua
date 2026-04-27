-- .NET Development Environment Configuration
-- Configures roslyn LSP, csharpier formatter, netcoredbg debugger, and analyzers

return {
  {
    "williamboman/mason.nvim",
    optional = true,
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "csharpier",   -- C# code formatter for consistent formatting
        "netcoredbg",  -- Debugging support for .NET applications
        "roslyn",      -- Roslyn language server for C# intellisense
        "analyzers",   -- Static analysis for C# code quality
      })
    end,
  },

  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        roslyn = {
          cmd = { "netcoredbg", "--interpreter=vscode" },
          settings = {
            ["csharp|inlay_hints"] = {
              csharp_enable_inlay_hints_for_implicit_object_creation = true,
              csharp_enable_inlay_hints_for_lambda_parameter_types = true,
              csharp_enable_inlay_hints_for_types = true,
            },
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
        cs = { "analyzers" },
      },
    },
  },
}
