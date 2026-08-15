-- Freitask: task tracking baseado em Obsidian, dirigido por Snacks.picker.
--
-- O código vive em ~/projects/freitask.nvim (repo próprio) desde que passou de
-- 3.000 linhas: era um aplicativo hospedado dentro do dotfiles, com testes e
-- CLI, e o histórico dele se misturava ao de config de shell e tmux.
--
-- Carregado por `dir=` em vez de por URL: é um clone local que eu edito, então
-- um `Lazy update` não deve nem tentar buscar dele. Se o clone não existir,
-- o spec se desativa em silêncio em vez de derrubar o startup do Neovim —
-- `nvim/hooks/check.sh` é quem reclama da ausência.
--
-- UI: picker de 2 níveis (projetos → tasks). Criação (<C-t>) e edição (<C-e> ou
-- <leader>oe sobre um callout, em CURRENT.md ou no arquivo da task) usam o MESMO
-- form flutuante posicional. Ver docs/ no repo do plugin.

local repo = vim.fn.expand("~/projects/freitask.nvim")

if vim.fn.isdirectory(repo) ~= 1 then
  return {}
end

return {
  dir = repo,
  name = "freitask.nvim",
  dependencies = { "folke/snacks.nvim" },
  event = "VeryLazy",
  -- `config`, não `init`: o init do lazy.nvim roda ANTES do plugin ser
  -- carregado, e é o carregamento que põe `dir` no runtimepath. Quando o
  -- freitask morava dentro de nvim/lua/ o require funcionava em qualquer
  -- momento; agora não mais.
  config = function()
    require("freitask").setup_autocmd()
  end,
  keys = {
    {
      "<leader>ob",
      function()
        require("freitask").open_projects()
      end,
      desc = "Freitask (Obsidian)",
    },
  },
}
