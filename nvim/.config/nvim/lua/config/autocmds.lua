-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Impede que o LazyVim ative o spell automaticamente em Markdown e outros arquivos de texto
vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Ativa soft wrap apenas para arquivos Markdown
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.spell = true -- Habilita corretor para escrita
  end,
})

-- Atalho customizado para "Modo Escrita" (Zen + Wrap + Spell)
vim.keymap.set("n", "<leader>uw", function()
  vim.cmd("ZenMode")
  -- O ZenMode pode resetar algumas opções, então garantimos que wrap/spell fiquem ativos se estivermos em markdown
  if vim.bo.filetype == "markdown" then
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end
end, { desc = "Toggle Writing Mode (Zen + Wrap + Spell)" })
