-- Copilot começa desligado em todo Neovim. Sem o texto fantasma (vim.g.ai_cmp),
-- ele só chega como fonte do blink.cmp, e o blink-copilot não devolve nada
-- enquanto o cliente está desligado. Liga e desliga com <leader>uP
-- (config/keymaps.lua).
return {
  {
    "zbirenbaum/copilot.lua",
    config = function(_, opts)
      require("copilot").setup(opts)
      require("copilot.command").disable()
    end,
  },
}
