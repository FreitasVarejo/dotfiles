-- Autocommands are automatically loaded on the VeryLazy event
-- Default autocommands that are always set:
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocommands here

-- Garante que o spell check esteja desativado para markdown,
-- já que o extra de markdown do LazyVim costuma habilitá-lo.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown" },
  callback = function()
    vim.opt_local.spell = false
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "cs" },
  callback = function()
    vim.diagnostic.config({
      virtual_text = {
        severity = { min = vim.diagnostic.severity.WARN },
      },
    }, { scope = "local" })
  end,
})

vim.api.nvim_create_autocmd("User", {
  pattern = "LazyDone",
  callback = function()
    pcall(vim.keymap.del, "n", "<leader>e")
    pcall(vim.keymap.del, "n", "<leader>E")
  end,
})

-- Espelha para o clipboard (OSC 52) apenas o yank explicito: 'd', 'x' e 'c'
-- passam pelo registrador sem nome mas nao devem esmagar o clipboard.
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    local ev = vim.v.event
    if ev.operator == "y" and (ev.regname == "" or ev.regname == "+") then
      local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
      if ok then
        osc52.copy("+")(ev.regcontents, ev.regtype)
      end
    end
  end,
})
