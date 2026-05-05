return {
  -- TreeSitter support for C#, Razor, and related languages
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "c_sharp",     -- C# language
        "html",        -- HTML (for Razor)
        "css",         -- CSS (for Blazor/Razor)
        "javascript",  -- JavaScript (for ASP.NET Core)
        "json",        -- JSON (appsettings.json)
        "yaml",        -- YAML (docker-compose, CI/CD)
        "xml",         -- XML (csproj files)
      },
    },
  },

  -- Mason packages for .NET development
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "roslyn",     -- Roslyn LSP (C# language server)
        "csharpier",  -- C# code formatter
        "netcoredbg", -- .NET debugger
      },
    },
  },

  -- LSP Configuration for Roslyn
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        roslyn = {
          filetypes = { "cs", "csproj", "cshtml" }, -- C#, project files, Razor
          settings = {
            -- Inlay hints configuration
            ["csharp|inlay_hints"] = {
              csharp_enable_inlay_hints_for_implicit_object_creation = true,
              csharp_enable_inlay_hints_for_implicit_variable_types = true,
              csharp_enable_inlay_hints_for_lambda_parameter_types = true,
              csharp_enable_inlay_hints_for_types = true,
              dotnet_enable_inlay_hints_for_indexer_parameters = true,
              dotnet_enable_inlay_hints_for_literal_parameters = true,
              dotnet_enable_inlay_hints_for_object_creation_parameters = true,
              dotnet_enable_inlay_hints_for_other_parameters = true,
              dotnet_enable_inlay_hints_for_parameters = true,
              dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
              dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
              dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
            },
            -- Code lens configuration
            ["csharp|code_lens"] = {
              dotnet_enable_references_code_lens = true,
              dotnet_enable_tests_code_lens = true,
            },
            -- Enable semantic highlighting
            ["csharp|background_analysis"] = {
              dotnet_analyzer_diagnostics_scope = "fullSolution",
              dotnet_compiler_diagnostics_scope = "fullSolution",
            },
            -- ASP.NET Core specific
            ["razor"] = {
              enable = true,
            },
          },
        },
      },
    },
  },

  -- EditorConfig support (respects .editorconfig files)
  {
    "gpanders/editorconfig.nvim",
    event = "BufReadPre",
  },

  -- Debug Adapter Protocol (DAP) for .NET with netcoredbg
  {
    "mfussenegger/nvim-dap",
    optional = true,
    opts = function()
      local dap = require("dap")

      -- Configure netcoredbg adapter
      if not dap.adapters["netcoredbg"] then
        dap.adapters["netcoredbg"] = {
          type = "executable",
          command = vim.fn.exepath("netcoredbg"),
          args = { "--interpreter=vscode" },
          options = {
            detached = false,
          },
        }
      end

      -- Configure debug configurations for C#
      if not dap.configurations["cs"] then
        dap.configurations["cs"] = {
          {
            type = "netcoredbg",
            name = "Launch file",
            request = "launch",
            program = function()
              return vim.fn.input("Path to dll: ", vim.fn.getcwd() .. "/", "file")
            end,
            cwd = "${workspaceFolder}",
          },
        }
      end
    end,
  },

  -- Testing support with neotest and neotest-vstest
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = {
      "Issafalcon/neotest-vstest",
    },
    opts = {
      adapters = {
        ["neotest-vstest"] = {
          -- Configuration for neotest-vstest
        },
      },
    },
  },

  -- Formatting with conform.nvim - format on save for C#
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        cs = { "csharpier" },
        cshtml = { "csharpier" }, -- Razor files
      },
      format_on_save = {
        timeout_ms = 3000,
        lsp_fallback = true,
      },
    },
  },

  -- ASP.NET Core snippets
  {
    "rafamadriz/friendly-snippets",
    opts = function()
      require("luasnip.loaders.from_vscode").lazy_load({
        paths = { vim.fn.stdpath("data") .. "/lazy/friendly-snippets" },
      })
    end,
  },

  -- File type detection for Razor
  {
    "jlcrochet/vim-razor",
    ft = { "cshtml", "razor" },
  },
}
