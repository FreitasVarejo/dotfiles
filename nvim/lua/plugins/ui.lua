return {
  -- Pasta aberta na linha de comando fica com o explorer do Snacks; o yazi é
  -- só por tecla ou :Yazi (que o próprio plugin registra, com cwd/toggle/logs).
  -- Duas teclas: <leader>- no arquivo atual e <leader>cw no cwd.
  {
    "mikavilpas/yazi.nvim",
    event = "VeryLazy",
    keys = {
      {
        "<leader>-",
        function()
          require("yazi").yazi()
        end,
        desc = "Open yazi at the current file",
      },
      {
        "<leader>cw",
        function()
          require("yazi").yazi(nil, vim.fn.getcwd())
        end,
        desc = "Open yazi at the current working directory",
      },
    },
  },

  -- Nome do grupo <leader>y (copiar referência para o agente, em
  -- config/keymaps.lua). O function form acrescenta ao `opts.spec` do LazyVim
  -- em vez de substituí-lo.
  {
    "folke/which-key.nvim",
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      table.insert(opts.spec, { "<leader>y", group = "yank ref", mode = { "n", "x" } })
    end,
  },

  {
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
    },
  },

  {
    "folke/snacks.nvim",
    opts = {
      image = { enabled = false },
      -- O preset nvim-remote do lazygit abre com --remote-tab, uma tab por
      -- arquivo. Aqui o `e` (edit) e o `e` num hunk (editAtLine) abrem o
      -- arquivo na janela de onde o lazygit foi aberto: o comando manda `q` ao
      -- lazygit, troca para essa janela (config/lazygit.lua guarda a origem,
      -- pelos mapas <leader>gg/gG de config/keymaps.lua) e só então faz o
      -- --remote, indo à linha no editAtLine. A troca sai do modo terminal
      -- antes do :drop; era ele rodando com o float ainda em modo terminal
      -- que desfazia o cursor posicionado na linha. Sem $NVIM abre direto.
      -- Adaptado de craftzdog/dotfiles@c6bad80 (lua/craftzdog/utils/lazygit.lua).
      lazygit = {
        config = {
          os = {
            edit = require("config.lazygit").edit_command(),
            editAtLine = require("config.lazygit").edit_command({ at_line = true }),
          },
        },
      },
      dashboard = {
        preset = {
          header = [[
 ██████╗ ████████╗ ██████╗     ██████╗  █████╗  ██████╗████████╗██╗   ██╗ █████╗ ██╗
 ██╔══██╗╚══██╔══╝██╔════╝     ██╔══██╗██╔══██╗██╔════╝╚══██╔══╝██║   ██║██╔══██╗██║
 ██████╔╝   ██║   ██║  ███╗    ██████╔╝███████║██║        ██║   ██║   ██║███████║██║
 ██╔══██╗   ██║   ██║   ██║    ██╔═══╝ ██╔══██║██║        ██║   ██║   ██║██╔══██║██║
     ██████╔╝   ██║   ╚██████╔╝    ██║     ██║  ██║╚██████╗   ██║   ╚██████╔╝██║  ██║███████╗
     ╚═════╝    ╚═╝    ╚═════╝     ╚═╝     ╚═╝  ╚═╝ ╚═════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝
          ]],
        },
      },
    },
  },

  -- Barra enxuta: o caminho inteiro até o arquivo, parando no nome (sem o
  -- símbolo do trouble), e sem o Copilot, o comando pendente, o progresso e a
  -- posição. O LazyVim monta cada seção numa lista posicional (e o extra do
  -- Copilot insere um item no meio), então as seções entram inteiras, e não
  -- filtradas por índice.
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      local icons = LazyVim.config.icons

      opts.sections.lualine_c = {
        LazyVim.lualine.root_dir(),
        {
          "diagnostics",
          -- O lualine conta os diagnostics mesmo com o buffer desligado.
          cond = function()
            return vim.diagnostic.is_enabled({ bufnr = 0 })
          end,
          symbols = {
            error = icons.diagnostics.Error,
            warn = icons.diagnostics.Warn,
            info = icons.diagnostics.Info,
            hint = icons.diagnostics.Hint,
          },
        },
        { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
        { LazyVim.lualine.pretty_path({ length = 0 }) },
      }

      -- Itens de uma linha, como no LazyVim; o stylua os expandiria.
      -- stylua: ignore
      opts.sections.lualine_x = {
        Snacks.profiler.status(),
        {
          function() return require("noice").api.status.mode.get() end,
          cond = function() return package.loaded["noice"] and require("noice").api.status.mode.has() end,
          color = function() return { fg = Snacks.util.color("Constant") } end,
        },
        {
          function() return "  " .. require("dap").status() end,
          cond = function() return package.loaded["dap"] and require("dap").status() ~= "" end,
          color = function() return { fg = Snacks.util.color("Debug") } end,
        },
        {
          require("lazy.status").updates,
          cond = require("lazy.status").has_updates,
          color = function() return { fg = Snacks.util.color("Special") } end,
        },
        {
          "diff",
          symbols = {
            added = icons.git.added,
            modified = icons.git.modified,
            removed = icons.git.removed,
          },
          source = function()
            local gitsigns = vim.b.gitsigns_status_dict
            if gitsigns then
              return {
                added = gitsigns.added,
                modified = gitsigns.changed,
                removed = gitsigns.removed,
              }
            end
          end,
        },
      }

      opts.sections.lualine_y = {}
    end,
  },

  -- Browser preview of markdown is not used; render in-buffer instead.
  {
    "iamcco/markdown-preview.nvim",
    enabled = false,
  },
}
