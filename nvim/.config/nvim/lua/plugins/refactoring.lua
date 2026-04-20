return {
  {
    "ThePrimeagen/refactoring.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      require("refactoring").setup()
      -- Agora o Telescope está garantido de estar carregado aqui
      require("telescope").load_extension("refactoring")
    end,
    keys = {
      {
        "<leader>re",
        ":Refactor extract<CR>",
        mode = "x",
        desc = "Extrair Função",
      },
      {
        "<leader>rf",
        ":Refactor extract_to_file<CR>",
        mode = "x",
        desc = "Extrair Função para Ficheiro",
      },
      {
        "<leader>rv",
        ":Refactor extract_var<CR>",
        mode = "x",
        desc = "Extrair Variável",
      },
      {
        "<leader>ri",
        ":Refactor inline_var<CR>",
        mode = { "n", "x" },
        desc = "Inline Variável",
      },
      {
        "<leader>rr",
        function()
          require("telescope").extensions.refactoring.refactors()
        end,
        mode = { "n", "x" },
        desc = "Menu de Refactoring",
      },
    },
  },
}
