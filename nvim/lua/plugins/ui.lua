return {
  -- Pasta aberta na linha de comando fica com o explorer do Snacks; o yazi é
  -- só por tecla ou :Yazi (que o próprio plugin registra, com cwd/toggle/logs).
  {
    "mikavilpas/yazi.nvim",
    event = "VeryLazy",
    keys = {
      -- Uma tecla só; troca o <BS> nativo do modo normal (anda para a esquerda).
      {
        "<BS>",
        function()
          require("yazi").yazi()
        end,
        desc = "Open yazi at the current file",
      },
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
      {
        "<leader>y",
        function()
          require("yazi").toggle()
        end,
        desc = "Toggle the last yazi session",
      },
    },
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
      -- arquivo. Aqui o `e` carrega os selecionados como buffers na janela em
      -- que o Neovim estava; o `q` fecha o lazygit antes de o arquivo abrir.
      -- Só o `edit`: o editAtLine (e num hunk) fica com o preset, que abre tab.
      -- Com --remote o `:drop` roda com o float ainda em modo terminal, e ao
      -- sair desse modo o Neovim desfaz o cursor posicionado na linha.
      lazygit = {
        config = {
          os = {
            edit = '[ -z "$NVIM" ] && (nvim -- {{filename}}) || (nvim --server "$NVIM" --remote-send "q" && nvim --server "$NVIM" --remote {{filename}})',
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
