return {
  -- O pacote `roslyn` (que o roslyn.nvim usa) vem do registro Crashdummyy.
  -- `registries` não soma entre specs (não há opts_extend): a lista inteira
  -- vale, por isso repete o oficial.
  {
    "mason-org/mason.nvim",
    opts = {
      registries = {
        "github:Crashdummyy/mason-registry",
        "github:mason-org/mason-registry",
      },
      ensure_installed = { "roslyn", "netcoredbg" },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      -- html, javascript, json, yaml e xml já são default do LazyVim.
      ensure_installed = {
        "c_sharp",
        "razor",
        "css",
      },
    },
  },

  -- C# e Razor pelo seblyng/roslyn.nvim (cliente "roslyn"); o roslyn_ls do
  -- lspconfig fica desligado para os dois não disputarem o buffer.
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- Idem para os outros servidores de C# que o Mason tenha instalado: o
      -- mason-lspconfig ligaria cada um sozinho.
      for _, server in ipairs({ "roslyn_ls", "omnisharp", "csharp_ls" }) do
        opts.servers[server] = { enabled = false }
      end
      -- Inlay hints pesam numa solution de dezenas de projetos; o servidor
      -- continua configurado para o <leader>uh ligar no buffer quando preciso.
      opts.inlay_hints = opts.inlay_hints or {}
      opts.inlay_hints.exclude = vim.list_extend(opts.inlay_hints.exclude or {}, { "cs", "razor" })
      -- Em C#, virtual text só de Warning para cima; Hint e Info do Roslyn
      -- poluem cada linha. A config de diagnóstico é global (não há escopo por
      -- buffer), então o filtro é uma função que olha o filetype. Montada só
      -- depois de o LazyVim aplicar opts.diagnostics: é no config dele que
      -- prefix = "icons" vira função, e ele só faz isso numa tabela.
      vim.api.nvim_create_autocmd("User", {
        pattern = "LazyLoad",
        callback = function(ev)
          if ev.data ~= "nvim-lspconfig" then
            return
          end
          local virtual_text = vim.diagnostic.config().virtual_text
          if type(virtual_text) == "table" then
            local cs_virtual_text = vim.tbl_extend("force", virtual_text, {
              severity = { min = vim.diagnostic.severity.WARN },
            })
            vim.diagnostic.config({
              virtual_text = function(_, bufnr)
                return vim.bo[bufnr].filetype == "cs" and cs_virtual_text or virtual_text
              end,
            })
          end
          return true
        end,
      })
      return opts
    end,
  },

  {
    "seblyng/roslyn.nvim",
    ft = { "cs", "razor" },
    init = function()
      vim.filetype.add({ extension = { razor = "razor", cshtml = "razor" } })

      -- Antes do plugin: o lazy sourceia plugin/roslyn.lua (vim.lsp.enable)
      -- antes do opts. O binário do Mason se chama `roslyn`, não o
      -- roslyn-language-server que o plugin procura, e o cmd dele passa
      -- --daemon-mode, que o servidor do Mason não aceita.
      -- No init o Mason ainda não pôs o bin/ dele no PATH: procura direto lá.
      local bin = ""
      for _, cand in ipairs({ vim.fn.stdpath("data") .. "/mason/bin/roslyn", "roslyn", "roslyn-language-server" }) do
        bin = vim.fn.exepath(cand)
        if bin ~= "" then
          break
        end
      end
      vim.lsp.config("roslyn", {
        cmd = bin ~= "" and { bin, "--stdio", "--clientProcessId", tostring(vim.uv.os_getpid()) } or nil,
        capabilities = {
          workspace = { didChangeWatchedFiles = { dynamicRegistration = true } },
          -- Sem registro dinâmico de format, ele não reanuncia o que o
          -- LspAttach abaixo tira.
          textDocument = {
            formatting = { dynamicRegistration = false },
            rangeFormatting = { dynamicRegistration = false },
            onTypeFormatting = { dynamicRegistration = false },
          },
        },
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
      })

      -- Sem format do Roslyn: o save não passa o arquivo pelo formatter do
      -- servidor, que lê o .editorconfig (end_of_line = crlf, git em LF).
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("roslyn_no_format", { clear = true }),
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client.name == "roslyn" then
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
            client.server_capabilities.documentOnTypeFormattingProvider = nil
            vim.b[args.buf].autoformat = false
          end
        end,
      })

      -- Com filewatching = "off" o servidor não observa nada; o save avisa
      -- do arquivo para completion e go-to-definition o enxergarem.
      -- build/run/test/clean da solution no <localleader> (config/dotnet.lua).
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("dotnet_keymaps", { clear = true }),
        pattern = { "cs", "razor" },
        callback = function(args)
          require("config.dotnet").keymaps(args.buf)
        end,
      })

      local group = vim.api.nvim_create_augroup("roslyn_watched_files", { clear = true })
      vim.api.nvim_create_autocmd("BufNewFile", {
        group = group,
        pattern = { "*.cs", "*.razor", "*.cshtml" },
        callback = function(args)
          vim.b[args.buf].roslyn_created = true
        end,
      })
      vim.api.nvim_create_autocmd("BufWritePost", {
        group = group,
        pattern = { "*.cs", "*.razor", "*.cshtml" },
        callback = function(args)
          local created = vim.b[args.buf].roslyn_created
          vim.b[args.buf].roslyn_created = nil
          local change = {
            uri = vim.uri_from_fname(vim.api.nvim_buf_get_name(args.buf)),
            type = created and vim.lsp.protocol.FileChangeType.Created or vim.lsp.protocol.FileChangeType.Changed,
          }
          for _, client in ipairs(vim.lsp.get_clients({ name = "roslyn" })) do
            client:notify("workspace/didChangeWatchedFiles", { changes = { change } })
          end
        end,
      })
    end,
    opts = {
      -- "off" descarta o watcher que o servidor registra: com ~40 projetos ele
      -- abriria uma instância de inotify por projeto e reanalisaria a solution
      -- a cada escrita em bin/obj. Quem avisa de mudança é o BufWritePost acima.
      filewatching = "off",
      -- Gruda na solution escolhida (vim.g.roslyn_nvim_selected_solution): um
      -- salto para um submódulo com outra .slnx não sobe um segundo cliente.
      lock_target = true,
    },
    keys = {
      { "<leader>rt", "<cmd>Roslyn target<cr>", desc = "Roslyn: escolher solution" },
      { "<leader>rr", "<cmd>lsp restart roslyn<cr>", desc = "Roslyn: reiniciar" },
    },
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
}
