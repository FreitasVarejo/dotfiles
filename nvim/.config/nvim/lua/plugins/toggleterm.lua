return {
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
}
