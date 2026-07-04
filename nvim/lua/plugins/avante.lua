return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  version = false,
  opts = {
    provider = "copilot",
    mode = "agentic",
    cursor_applying_provider = "copilot",
    mappings = {
      submit = {
        insert = "<C-CR>",
      },
    },
    acp_providers = {
      cursor = {
        command = { vim.fn.exepath("agent") or vim.fn.expand("~/.local/bin/agent") },
      },
    },
  },
  dependencies = {
    "stevearc/dressing.nvim",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "zbirenbaum/copilot.lua",
  },
  env = {
    HOME = vim.env.HOME,
    PATH = vim.env.PATH,
    CURSOR_API_KEY = vim.env.CURSOR_API_KEY,
    CURSOR_AUTH_TOKEN = vim.env.CURSOR_AUTH_TOKEN,
  },
}