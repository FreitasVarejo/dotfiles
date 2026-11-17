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

-- Diagnostics por buffer: o markdown abre desligado (config/autocmds.lua). O
-- toggle do LazyVim é global e lê vim.diagnostic.is_enabled() sem buffer, que
-- vira false assim que um único buffer é desligado; ele passaria a mostrar
-- "off" em todos os outros. Este troca o <leader>ud pelo do buffer atual.
Snacks.toggle({
  name = "Diagnostics",
  get = function()
    return vim.diagnostic.is_enabled({ bufnr = 0 })
  end,
  set = function(state)
    vim.diagnostic.enable(state, { bufnr = 0 })
  end,
}):map("<leader>ud")

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

-- Copiar referência de arquivo para colar num agente (config/editor.lua).
-- Vai para o clipboard (+); em SSH o g:clipboard de options.lua leva por OSC 52.
vim.keymap.set({ "n", "x" }, "<leader>yf", function()
  require("config.editor").yank_path_with_line(false)
end, { desc = "Yank relative path#line" })
vim.keymap.set({ "n", "x" }, "<leader>yp", function()
  require("config.editor").yank_path_with_line(true)
end, { desc = "Yank absolute path#line" })
vim.keymap.set("x", "<leader>yc", function()
  require("config.editor").copy_as_codeblock()
end, { desc = "Yank selection as Markdown codeblock" })

-- Buffers ocultos (config/editor.lua). O <leader>b é o grupo de buffers do
-- LazyVim.
vim.keymap.set("n", "<leader>bh", function()
  require("config.editor").delete_hidden_buffers()
end, { desc = "Delete Hidden Buffers" })

-- Arquivo como estava no commit do blame da linha (config/editor.lua).
vim.keymap.set("n", "<leader>go", function()
  require("config.editor").open_blamed_file()
end, { desc = "Open file from blamed commit" })

-- Lazygit: o `e` do lazygit abre o arquivo na janela de onde ele foi aberto,
-- então a janela de origem é guardada ao abrir (config/lazygit.lua; o comando
-- fica em plugins/ui.lua). Redefine os dois mapas que o LazyVim cria em
-- lazyvim/config/keymaps.lua, só se o lazygit é executável, com os mesmos
-- argumentos.
if vim.fn.executable("lazygit") == 1 then
  vim.keymap.set("n", "<leader>gg", function()
    require("config.lazygit").open({ cwd = LazyVim.root.git() })
  end, { desc = "Lazygit (Root Dir)" })
  vim.keymap.set("n", "<leader>gG", function()
    require("config.lazygit").open()
  end, { desc = "Lazygit (cwd)" })
end

-- Sobreposição de diff no buffer, só com o gitsigns (<leader>uO: o <leader>uG é
-- o toggle de signs do gitsigns, que o LazyVim mapeia ao carregá-lo): linhas coloridas, diff
-- por palavra e linhas removidas inline. O get lê a config do gitsigns e, com
-- ele ainda não carregado, devolve false sem carregá-lo.
-- Adaptado de craftzdog/dotfiles@c6bad80 (plugins/keymaps.lua, toggle do overlay do
-- mini.diff), trocando o mini.diff pelo gitsigns.
Snacks.toggle({
  name = "Git Diff Overlay",
  get = function()
    local config = package.loaded["gitsigns.config"]
    local c = config and config.config
    return c ~= nil and (c.linehl and c.show_deleted and c.word_diff) == true
  end,
  set = function(state)
    local ok, gitsigns = pcall(require, "gitsigns")
    if not ok then
      vim.notify("gitsigns indisponível", vim.log.levels.WARN)
      return
    end
    gitsigns.toggle_linehl(state)
    gitsigns.toggle_word_diff(state)
    gitsigns.toggle_deleted(state)
  end,
}):map("<leader>uO")
