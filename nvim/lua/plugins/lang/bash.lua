-- O bashls e o shellcheck no Mason vêm do extra util.dot; o shfmt, do LazyVim.
-- Aqui fica só o que eles não ligam: o shellcheck como linter e o shfmt no
-- filetype bash.
return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        bash = { "shellcheck" },
        sh = { "shellcheck" },
      },
    },
  },

  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        bash = { "shfmt" },
        sh = { "shfmt" },
      },
    },
  },
}
