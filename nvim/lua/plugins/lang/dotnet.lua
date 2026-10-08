return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "c_sharp",
        "html",
        "css",
        "javascript",
        "json",
        "yaml",
        "xml",
      },
    },
  },

  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers.roslyn_ls = {
        mason = false,
        cmd = (function()
          local cmd = vim.fn.exepath("roslyn")
          if cmd == "" then
            cmd = vim.fn.exepath("roslyn-language-server")
          end
          return { cmd, "--stdio" }
        end)(),
        filetypes = { "cs" },
        settings = {
          ["csharp|inlay_hints"] = {
            csharp_enable_inlay_hints_for_implicit_object_creation = true,
            csharp_enable_inlay_hints_for_implicit_variable_types = true,
            csharp_enable_inlay_hints_for_lambda_parameter_types = true,
            csharp_enable_inlay_hints_for_types = true,
          },
          ["csharp|code_lens"] = {
            dotnet_enable_references_code_lens = false,
            dotnet_enable_tests_code_lens = false,
          },
          ["csharp|background_analysis"] = {
            dotnet_analyzer_diagnostics_scope = "openFiles",
            dotnet_compiler_diagnostics_scope = "openFiles",
          },
        },
        -- Sem format do Roslyn: o save não passa o arquivo pelo formatter do
        -- servidor, que lê o .editorconfig (end_of_line = crlf, git em LF).
        -- Sem registro dinâmico, ele não reanuncia o que o on_attach tira.
        capabilities = {
          textDocument = {
            formatting = { dynamicRegistration = false },
            rangeFormatting = { dynamicRegistration = false },
            onTypeFormatting = { dynamicRegistration = false },
          },
        },
      }
      opts.setup = opts.setup or {}
      opts.setup.roslyn_ls = function()
        Snacks.util.lsp.on({ name = "roslyn_ls" }, function(_, client)
          client.server_capabilities.documentFormattingProvider = false
          client.server_capabilities.documentRangeFormattingProvider = false
          client.server_capabilities.documentOnTypeFormattingProvider = nil
        end)
      end
      -- Inlay hints pesam numa solution de dezenas de projetos; ficam
      -- configurados acima para o <leader>uh ligar no buffer quando preciso.
      opts.inlay_hints = opts.inlay_hints or {}
      opts.inlay_hints.exclude = vim.list_extend(opts.inlay_hints.exclude or {}, { "cs" })
      return opts
    end,
  },

  {
    "gpanders/editorconfig.nvim",
    event = "BufReadPre",
  },

  {
    "mfussenegger/nvim-dap",
    optional = true,
    opts = function()
      local dap = require("dap")
      if not dap.adapters["netcoredbg"] then
        dap.adapters["netcoredbg"] = {
          type = "executable",
          command = vim.fn.exepath("netcoredbg"),
          args = { "--interpreter=vscode" },
          options = { detached = false },
        }
      end
      if not dap.configurations["cs"] then
        dap.configurations["cs"] = {
          {
            type = "netcoredbg",
            name = "Launch file",
            request = "launch",
            program = function()
              local sln = require("config.dotnet").solution()
              local dir = sln and vim.fs.dirname(sln) or vim.fn.getcwd()
              return vim.fn.input("Path to dll: ", dir .. "/", "file")
            end,
            cwd = "${workspaceFolder}",
          },
        }
      end
      -- Um launch por *.Host.dll de Debug debaixo da solution do buffer, com
      -- cwd no projeto do host (onde estão os appsettings) e não no cwd do nvim.
      dap.providers.configs["dotnet-solution"] = function(bufnr)
        local dotnet = require("config.dotnet")
        local sln = vim.bo[bufnr].filetype == "cs" and dotnet.solution(bufnr)
        if not sln then
          return {}
        end
        return vim.tbl_map(function(dll)
          return {
            type = "netcoredbg",
            name = "Launch " .. vim.fn.fnamemodify(dll, ":t:r"),
            request = "launch",
            program = dll,
            cwd = (dll:gsub("/bin/Debug/[^/]+/[^/]+$", "")),
          }
        end, dotnet.host_dlls(sln))
      end
    end,
  },

  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = {
      "Nsidorenco/neotest-vstest",
    },
    opts = {
      adapters = {
        ["neotest-vstest"] = {},
      },
    },
  },

  {
    "rafamadriz/friendly-snippets",
    dependencies = { "L3MON4D3/LuaSnip" },
    config = function()
      require("luasnip.loaders.from_vscode").lazy_load({
        paths = { vim.fn.stdpath("data") .. "/lazy/friendly-snippets" },
      })
    end,
  },

  {
    "jlcrochet/vim-razor",
    ft = { "cshtml", "razor" },
  },
}
