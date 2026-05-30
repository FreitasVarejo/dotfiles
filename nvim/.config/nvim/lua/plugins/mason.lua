return {
  "mason-org/mason.nvim",
  cmd = "Mason",
  keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
  opts = {
    ui = {
      border = "rounded",
      icons = {
        package_installed = "✓",
        package_pending = "➜",
        package_uninstalled = "✗",
      },
    },
    registries = {
      "github:Crashdummyy/mason-registry", -- Custom registry (includes Roslyn)
      "github:mason-org/mason-registry",   -- Official Mason registry
    },
    ensure_installed = {
      -- TypeScript / JavaScript
      "vtsls",           -- TypeScript language server
      "prettier",        -- Code formatter

      -- C# / .NET
      "roslyn",          -- Roslyn C# language server
      "csharpier",       -- C# code formatter
      "netcoredbg",      -- .NET debugger

       -- Linting
       "eslint-lsp",      -- ESLint language server
       "eslint_d",        -- Fast eslint runner
       "shellcheck",      -- Shell script linter
       "shfmt",           -- Shell script formatter

       -- Other
       "stylua",          -- Lua formatter
       "bash-language-server",  -- Bash language server
    },
  },
}
