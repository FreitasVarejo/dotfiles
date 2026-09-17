-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Habilita corretor para Inglês e Português
vim.opt.spelllang = { "en", "pt_br" }

-- Numeração relativa
vim.opt.number = true
vim.opt.relativenumber = true

-- Desativa o corretor ortográfico globalmente
vim.opt.spell = false

-- Mapeia blocos de código ```shell para usar o parser de bash
vim.treesitter.language.register("bash", "shell")

vim.opt.swapfile = false
vim.opt.timeoutlen = 300
vim.opt.ttimeoutlen = 100

-- Sob SSH o LazyVim deixa 'clipboard' vazio para nao atrapalhar o OSC 52
-- (lazyvim/config/options.lua). Fixamos o provider explicitamente: copiar via
-- OSC 52, colar lendo o registrador do proprio nvim -- o query OSC 52 de
-- *leitura* e recusado pela maioria dos terminais e faria cada "+p travar.
if vim.env.SSH_TTY or vim.env.SSH_CONNECTION then
  local osc52 = require("vim.ui.clipboard.osc52")
  local function paste_local()
    return vim.split(vim.fn.getreg('"'), "\n")
  end
  vim.g.clipboard = {
    name = "OSC 52",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = { ["+"] = paste_local, ["*"] = paste_local },
  }
end
