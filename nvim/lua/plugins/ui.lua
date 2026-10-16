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

  -- Browser preview of markdown is not used; render in-buffer instead.
  {
    "iamcco/markdown-preview.nvim",
    enabled = false,
  },
}
