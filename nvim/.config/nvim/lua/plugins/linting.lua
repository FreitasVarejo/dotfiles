return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        bash = { "shellcheck" },
        sh = { "shellcheck" },
        -- Bash code blocks in Markdown
        markdown = { "shellcheck" },
      },
    },
  },
}
