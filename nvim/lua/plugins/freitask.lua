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
-- O regen do CURRENT.md ao salvar uma task à mão mora em config/autocmds.lua.

return {
  {
    "folke/snacks.nvim",
    keys = {
      {
        "<leader>k",
        function()
          Snacks.terminal("freitask", { win = { style = "lazygit" } })
        end,
        desc = "Freitask",
      },
    },
  },
}
