return {
  {
    "ThePrimeagen/refactoring.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("refactoring").setup()
      -- Carrega a extensão do Telescope
      require("telescope").load_extension("refactoring")
    end,
    keys = {
      { "<leader>re", function() require("refactoring").refactor("Extract Function") end, mode = "x", desc = "Extrair Função" },
      { "<leader>rf", function() require("refactoring").refactor("Extract Function To File") end, mode = "x", desc = "Extrair Função para Ficheiro" },
      { "<leader>rv", function() require("refactoring").refactor("Extract Variable") end, mode = "x", desc = "Extrair Variável" },
      { "<leader>ri", function() require("refactoring").refactor("Inline Variable") end, mode = { "n", "x" }, desc = "Inline Variável" },
      { "<leader>rr", function() require("telescope").extensions.refactoring.refactors() end, mode = { "n", "x" }, desc = "Menu de Refactoring" },
    },
  }
}
