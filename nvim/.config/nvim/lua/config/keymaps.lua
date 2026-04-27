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

-- Merge visual imports
local function merge_visual_imports()
  -- Quando um atalho é acionado no modo visual, as marcas '< e '> (início e fim da seleção)
  -- só são atualizadas na API quando saímos do modo visual.
  -- Por isso, simulamos a tecla <Esc> antes de rodar a lógica.
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)

  -- Usamos o vim.schedule para garantir que a lógica rode depois que o <Esc> foi processado
  vim.schedule(function()
    local start_row = vim.fn.line("'<")
    local end_row = vim.fn.line("'>")

    -- Pega o texto das linhas selecionadas
    local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
    local symbols = {}

    for _, line in ipairs(lines) do
      -- 1. Tenta extrair imports desestruturados: import { A, B } from "..."
      local destructured = line:match("import%s*{([^}]+)}")
      if destructured then
        for sym in destructured:gmatch("([^,]+)") do
          -- Remove espaços em branco antes e depois do nome do símbolo
          sym = sym:match("^%s*(.-)%s*$")
          if sym ~= "" then table.insert(symbols, sym) end
        end
      else
        -- 2. Tenta extrair importações padrão (default): import Componente from "..."
        local default_import = line:match("import%s+([%w_]+)%s+from")
        if default_import then
          table.insert(symbols, default_import)
        end
      end
    end

    if #symbols == 0 then
      vim.notify("Nenhum import válido encontrado na seleção.", vim.log.levels.WARN)
      return
    end

    -- Pede ao usuário o novo caminho (usando a UI nativa do Neovim)
    vim.ui.input({ prompt = "Novo path (ex: ./components): " }, function(input)
      -- Se o usuário der ESC ou enter vazio, cancela a operação
      if not input or input == "" then return end

      -- Remove as aspas do input, caso você digite acidentalmente com aspas
      input = input:gsub('^["\']', ''):gsub('["\']$', '')

      -- Monta a nova string de importação
      local new_import = string.format('import { %s } from "%s";', table.concat(symbols, ", "), input)

      -- Substitui as linhas selecionadas pela nova linha
      vim.api.nvim_buf_set_lines(0, start_row - 1, end_row, false, { new_import })

      -- Como você tem o conform.nvim configurado para format_on_save no seu setup,
      -- opcionalmente podemos apenas notificar, e ao salvar ( :w ),
      -- o Prettier vai quebrar a linha certinho se ela passar do max_width de 120 caracteres!
      vim.notify("Imports unificados!", vim.log.levels.INFO)
    end)
  end)
end

-- Registra o atalho EXCLUSIVAMENTE para o modo visual ("v")
vim.keymap.set(
  "v",
  "<leader>mi",
  merge_visual_imports,
  { desc = "Merge Imports" }
)

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

