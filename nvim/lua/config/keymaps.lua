local status_ok, discipline = pcall(require, "config.custom-mode.discipline")
if status_ok then
  discipline.cowboy()
end

-- O extra snacks_explorer põe <leader>e/E ao carregar o snacks, antes deste
-- arquivo. Num autocmd de User LazyDone não serve: sem arquivo na linha de
-- comando o LazyVim só carrega o autocmds.lua no VeryLazy, depois do LazyDone.
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

-- O Copilot sobe desligado (plugins/copilot.lua); este toggle liga e desliga.
-- O get não carrega o plugin: sem o módulo na memória ele está desligado. O
-- <leader>up é o toggle do Mini Pairs no LazyVim, daí o P maiúsculo.
Snacks.toggle({
  name = "Copilot",
  get = function()
    local client = package.loaded["copilot.client"]
    return client ~= nil and not client.is_disabled()
  end,
  set = function(state)
    local command = require("copilot.command")
    if state then
      command.enable()
    else
      command.disable()
    end
  end,
}):map("<leader>uP")

-- Build/run/test/clean de C# moram em config/dotnet.lua, no <localleader> do
-- buffer cs/razor.
