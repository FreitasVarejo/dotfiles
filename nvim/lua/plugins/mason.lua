return {
  "mason-org/mason.nvim",
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
      "github:mason-org/mason-registry", -- Official Mason registry
    },
    -- stylua, shfmt e prettier já vêm do LazyVim (core e extra formatting.prettier).
    ensure_installed = {
      -- TypeScript / JavaScript
      "tsgo", -- TypeScript language server (TS 7 nativo)

      -- C# / .NET
      -- tree-sitter-cli: install via cargo or ~/.local/bin, not Mason prebuilt
      "roslyn", -- Roslyn C# language server (format desligado: ver lang/dotnet.lua)
      "netcoredbg", -- .NET debugger

      -- Linting
      "eslint-lsp", -- ESLint language server
      "shellcheck", -- Shell script linter

      -- Bash
      "bash-language-server",
    },
  },
}
