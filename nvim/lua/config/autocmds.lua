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

-- Freitask: salvar uma task à mão regenera o CURRENT.md. Era o autocmd do
-- plugin freitask.nvim, que o Neovim não carrega mais (ver
-- plugins/freitask.lua); agora é a CLI, em segundo plano. `*` casa `/` em
-- pattern de autocmd, então as arquivadas também chegam aqui — e não estão no
-- painel, por isso são puladas.
vim.api.nvim_create_autocmd("BufWritePost", {
  group = vim.api.nvim_create_augroup("freitask", { clear = true }),
  pattern = vim.fn.expand("~/ObsidianVault/projects") .. "/*/tasks/*.md",
  callback = function(args)
    if args.match:find("/tasks/archived/", 1, true) or vim.fn.executable("freitask") == 0 then
      return
    end
    vim.system({ "freitask", "rebuild" }, { text = true }, function(r)
      if r.code ~= 0 then
        vim.schedule(function()
          vim.notify("freitask rebuild falhou: " .. vim.trim(r.stderr or ""), vim.log.levels.WARN)
        end)
      end
    end)
  end,
})

-- O editorconfig (end_of_line = crlf) põe fileformat=dos ao abrir, e o save
-- reescreveria em CRLF um arquivo que o git guarda em LF. Antes de gravar, se o
-- arquivo em disco é LF, ele continua LF; arquivo novo ou já CRLF segue o
-- editorconfig.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("keep_lf", { clear = true }),
  callback = function(args)
    if vim.bo[args.buf].fileformat ~= "dos" then
      return
    end
    local f = io.open(args.match, "rb")
    if not f then
      return
    end
    local head = f:read(65536) or ""
    f:close()
    if head:find("\n", 1, true) and not head:find("\r\n", 1, true) then
      vim.bo[args.buf].fileformat = "unix"
    end
  end,
})
