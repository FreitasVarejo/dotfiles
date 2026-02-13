return {
  -- Zen Mode: Foco total ocultando UI desnecessária
  {
    "folke/zen-mode.nvim",
    cmd = "ZenMode",
    opts = {
      window = {
        width = 120, -- largura da janela no modo zen
        options = {
          number = false,
          relativenumber = false,
          cursorline = false,
        },
      },
      plugins = {
        gitsigns = { enabled = false },
        tmux = { enabled = true },
        twilight = { enabled = true },
      },
    },
    keys = {
      { "<leader>uz", "<cmd>ZenMode<cr>", desc = "Toggle Zen Mode" },
    },
  },

  -- Twilight: Escurece o código fora do contexto atual
  {
    "folke/twilight.nvim",
    opts = {
      -- configurações padrão são boas
    },
  },

  -- Render Markdown: Melhora drasticamente a visualização de Markdown
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      file_types = { "markdown" },
    },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
  },
}
