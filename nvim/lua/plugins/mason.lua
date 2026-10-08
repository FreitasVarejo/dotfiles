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
      "tsgo",            -- TypeScript language server (TS 7 nativo)
      "prettier",        -- Code formatter

      -- C# / .NET
      -- tree-sitter-cli: install via cargo or ~/.local/bin, not Mason prebuilt
      "roslyn",          -- Roslyn C# language server (format desligado: ver lang/dotnet.lua)
      "netcoredbg",      -- .NET debugger

       -- Linting
       "eslint-lsp",      -- ESLint language server
       "shellcheck",      -- Shell script linter
       "shfmt",           -- Shell script formatter

       -- Other
       "stylua",          -- Lua formatter
       "bash-language-server",  -- Bash language server
    },
  },
}
