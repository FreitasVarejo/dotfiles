return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      file_types = { "markdown" },
      checkbox = {
        enabled = true,
      },
      -- Header sem o `#` e sem ícone, com o fundo da linha e o sinal na coluna
      -- da esquerda. O extra de markdown do LazyVim põe `icons = {}`, e com isso
      -- o `#` fica à mostra; a função devolve "" em todos os níveis (o plugin
      -- mescla `icons` por índice, então uma lista deixaria os outros níveis
      -- com ícone). `inline` põe o texto na margem; o padrão, `overlay`, deixa
      -- o espaço do `# ` em branco. O extra também põe `sign = false`.
      heading = {
        icons = function()
          return ""
        end,
        position = "inline",
        sign = true,
      },
    },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
  },
}
