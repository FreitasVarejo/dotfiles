-- Freitask: a TUI `freitask-tui` num terminal flutuante, do tamanho do lazygit.
--
-- O picker Snacks e o form que moravam no plugin freitask.nvim saíram: navegar
-- e mexer nas tasks é a TUI, que roda igual fora do Neovim (`freitask` no
-- terminal). O Neovim não carrega mais Lua nenhum do repo do freitask — quem
-- usa o repo é a CLI, que roda o motor sob `nvim -l`.
--
-- Fica fora do <leader>o de propósito: aquele grupo é do obsidian.nvim. Abrir
-- uma task de dentro da TUI a abre AQUI, no Neovim pai (via $NVIM), e fecha o
-- float; o `checktime` do LazyVim no TermClose recarrega o que ela mudou.
--
-- No dashboard é o `K`, maiúsculo porque o snacks reserva `hjklq` para andar na
-- lista; o `K` do LazyVim (hover) só existe em buffer com LSP. O item entra
-- logo depois do `n`, achado pela chave: o lazy.nvim substitui lista no merge
-- de `opts`, e o obsidian.lua troca esse `n` no lugar do mesmo jeito.
--
-- O regen do CURRENT.md ao salvar uma task à mão mora em config/autocmds.lua.

local function open()
  Snacks.terminal("freitask", { win = { style = "lazygit" } })
end

return {
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>k", open, desc = "Freitask" },
    },
    opts = function(_, opts)
      local items = vim.tbl_get(opts, "dashboard", "preset", "keys") or {}
      for i, item in ipairs(items) do
        if item.key == "n" then
          table.insert(items, i + 1, { icon = " ", key = "K", desc = "Freitask", action = open })
          break
        end
      end
    end,
  },
}
