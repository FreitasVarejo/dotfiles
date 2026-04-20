-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local status_ok, discipline = pcall(require, "config.discipline")
if status_ok then
  discipline.cowboy()
end

-- Disable neo-tree explorer keymaps (using yazi instead)
vim.keymap.del("n", "<leader>e")
vim.keymap.del("n", "<leader>E")

-- Pair Coding Mode Toggle
local pairmode = require("config.pairmode")
vim.keymap.set("n", "<leader>ee", function()
  pairmode.toggle()
end, { desc = "Toggle Pair Coding Mode" })

-- Resize splits with keyboard
vim.keymap.set("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
vim.keymap.set("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
vim.keymap.set("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
vim.keymap.set("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- Prettier format (using built-in vim.lsp.buf.format with prettier)
vim.keymap.set(
  { "n", "v" },
  "<leader>fm",
  function()
    vim.lsp.buf.format({ async = true })
  end,
  { desc = "Format (Prettier)" }
)

-- ESLint fix
vim.keymap.set("n", "<leader>el", "<cmd>EslintFixAll<cr>", { desc = "ESLint Fix All" })

