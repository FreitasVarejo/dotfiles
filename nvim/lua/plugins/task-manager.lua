-- Task Manager: task tracking baseado em Obsidian, dirigido por Snacks.picker.
--
-- Toda a lógica vive em `lua/util/tasks.lua` (parser/serializer do callout,
-- resolver de cursor, form de edição, dashboard CURRENT.md). Este arquivo é só
-- o spec do plugin: registra o autocmd (cache + keymap buffer-local <leader>oe)
-- e a keymap global <leader>ob do picker. Declarado como fragmento `optional`
-- do spec já configurado do snacks.nvim.
--
-- UI: picker de 2 níveis (projetos → tasks). A edição de uma task acontece num
-- form flutuante multi-campo, acionável tanto pelo picker (<C-e>) quanto pelo
-- <leader>oe quando o cursor está sobre um callout (em CURRENT.md ou no arquivo
-- da task).

local tasks = require("util.tasks")

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
      desc = "Task Manager (Obsidian)",
    },
  },
}
