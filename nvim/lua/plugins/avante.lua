return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  version = false,
  opts = {
    provider = "copilot",
    mode = "agentic",
    cursor_applying_provider = "copilot",
    behaviour = {
      auto_set_keymaps = false,
    },
    selection = {
      hint_display = "none",
    },
    mappings = {
      submit = {
        insert = "<C-CR>",
      },
    },
    acp_providers = {
      cursor = {
        command = function()
          local agent = vim.fn.exepath("agent") or vim.fn.expand("~/.local/bin/agent")
          return { agent, "acp" }
        end,
        auth = "cursor_login",
      },
    },
  },
  keys = function()
    local api = function(name)
      return function() require("avante.api")[name]() end
    end
    return {
      { "<leader>aa", api("ask"), desc = "Avante: Ask" },
      { "<leader>ac", function() require("avante.api").ask({ new_chat = true }) end, desc = "Avante: Chat (new)" },
      { "<leader>ae", api("edit"), desc = "Avante: Edit selection" },
      { "<leader>af", api("focus"), desc = "Avante: Focus sidebar" },
      { "<leader>ah", api("select_history"), desc = "Avante: History" },
      { "<leader>am", api("select_model"), desc = "Avante: Select model" },
      { "<leader>ap", "<cmd>AvanteProvider<cr>", desc = "Avante: Provider" },
      { "<leader>ar", api("refresh"), desc = "Avante: Refresh" },
      { "<leader>as", api("stop"), desc = "Avante: Stop" },
      {
        "<leader>at",
        function()
          local sidebar = require("avante").get()
          if sidebar and sidebar:is_open() then
            require("avante").close_sidebar()
          else
            require("avante").open_sidebar({})
          end
        end,
        desc = "Avante: Toggle sidebar",
      },
    }
  end,
  dependencies = {
    "stevearc/dressing.nvim",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "zbirenbaum/copilot.lua",
    {
      "Kaiser-Yang/blink-cmp-avante",
      optional = true,
      opts = {},
    },
  },
  env = {
    HOME = vim.env.HOME,
    PATH = vim.env.PATH,
    CURSOR_API_KEY = vim.env.CURSOR_API_KEY,
    CURSOR_AUTH_TOKEN = vim.env.CURSOR_AUTH_TOKEN,
  },
}
