-- Autocommands are automatically loaded on the VeryLazy event
-- Default autocommands that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocommands here

-- Garante que o spell check esteja desativado para markdown, 
-- já que o extra de markdown do LazyVim costuma habilitá-lo.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown" },
  callback = function()
    vim.opt_local.spell = false
  end,
})
