-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local status_ok, discipline = pcall(require, "config.custom-mode.discipline")
if status_ok then
  discipline.cowboy()
end

-- Disable neo-tree explorer keymaps (using yazi instead)
-- TODO: desativar o lugin do neo-tree todo
-- vim.keymap.del("n", "<leader>e")
-- vim.keymap.del("n", "<leader>E")

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

-- Prettier format (using built-in vim.lsp.buf.format with prettier)
vim.keymap.set({ "n", "v" }, "<leader>fm", function() end, { desc = "Format (Prettier)" })

-- ESLint fix
vim.keymap.set("n", "<leader>el", "<cmd>EslintFixAll<cr>", { desc = "ESLint Fix All" })

-- C# / .NET specific keymaps
vim.keymap.set("n", "<leader>cs", function()
  vim.cmd("!dotnet build")
end, { desc = "C# Build Solution" })

vim.keymap.set("n", "<leader>cr", function()
  vim.cmd("!dotnet run")
end, { desc = "C# Run Project" })

vim.keymap.set("n", "<leader>ct", function()
  vim.cmd("!dotnet test")
end, { desc = "C# Run Tests" })

vim.keymap.set("n", "<leader>cc", function()
  vim.cmd("!dotnet clean")
end, { desc = "C# Clean Solution" })

-- Show LSP status (Neovim 0.12+) - replacement for deprecated :LspInfo
vim.keymap.set("n", "<leader>ls", "<cmd>LspStatus<cr>", { desc = "Show LSP Status" })
