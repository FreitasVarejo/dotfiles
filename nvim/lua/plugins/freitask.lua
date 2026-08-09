-- Freitask: task tracking baseado em Obsidian, dirigido por Snacks.picker.
--
-- Toda a lógica vive em `lua/freitask/` (ver docs/freitask-internals.md para o
-- mapa dos módulos). Este arquivo é só o spec do plugin: registra o autocmd
-- (cache + keymap buffer-local <leader>oe) e a keymap global <leader>ob do
-- picker. Declarado como fragmento `optional` do spec já configurado do
-- snacks.nvim.
--
-- UI: picker de 2 níveis (projetos → tasks). Criação (<C-t>) e edição (<C-e> ou
-- <leader>oe sobre um callout, em CURRENT.md ou no arquivo da task) usam o MESMO
-- form flutuante posicional: título / id / "<tipo-de-callout> [descrição]" /
-- notas, com os rótulos em virtual text e <C-s> para escolher o status.
--
-- Arquivar/desarquivar (<C-r> no picker, <leader>oa no arquivo) ficam FORA do
-- form de propósito: são ações com confirmação, e um quarto campo posicional
-- faria uma linha apagada sem querer mover arquivo de lugar.

local tasks = require("freitask")

return {
  "folke/snacks.nvim",
  optional = true,
  init = function()
    tasks.setup_autocmd()
  end,
  keys = {
    {
      "<leader>ob",
      function()
        tasks.open_projects()
      end,
      desc = "Freitask (Obsidian)",
    },
  },
}
