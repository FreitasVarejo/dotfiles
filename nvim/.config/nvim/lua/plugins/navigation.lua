return {
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
    },
    keys = {
      { "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>" },
      { "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>" },
      { "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>" },
      { "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>" },
      { "<c-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>" },
    },
  },

  {
    "akinsho/toggleterm.nvim",
    version = "*",
    event = "VeryLazy",
    keys = {
      { "<leader>tt", "<cmd>ToggleTerm direction=vertical<cr>", desc = "Terminal (vertical)" },
      { "<leader>th", "<cmd>ToggleTerm direction=horizontal<cr>", desc = "Terminal (horizontal)" },
      { "<leader>tf", "<cmd>ToggleTerm direction=float<cr>", desc = "Terminal (float)" },
    },
    opts = {
      open_mapping = [[<c-\>]],
      direction = "vertical",
      size = 80,
      hide_numbers = true,
      shade_filetypes = {},
      autochdir = true,
    },
  },
}
