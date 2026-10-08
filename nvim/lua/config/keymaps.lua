-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local status_ok, discipline = pcall(require, "config.custom-mode.discipline")
if status_ok then
  discipline.cowboy()
end

pcall(vim.keymap.del, "n", "<leader>e")
pcall(vim.keymap.del, "n", "<leader>E")

-- Pair Coding Mode Toggle
local pairmode = require("config.custom-mode.pairmode")
vim.keymap.set("n", "<leader>ee", function()
  pairmode.toggle()
end, { desc = "Toggle Pair Coding Mode" })

-- Resize splits with keyboard
vim.keymap.set("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
vim.keymap.set("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
vim.keymap.set("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
vim.keymap.set("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- ESLint fix (o comando do eslint LSP do nvim-lspconfig, buffer-local)
vim.keymap.set("n", "<leader>el", "<cmd>LspEslintFixAll<cr>", { desc = "ESLint Fix All" })

-- Build/run/test/clean de C# moram em config/dotnet.lua, no <localleader> do
-- buffer cs/razor.
