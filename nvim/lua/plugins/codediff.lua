-- Adaptado de craftzdog/dotfiles@c6bad80 (plugins/ui.lua, bloco codediff).
return {
  {
    "esmuellert/codediff.nvim",
    cmd = "CodeDiff",
    keys = {
      { "<leader>gv", "<cmd>CodeDiff<cr>", desc = "Toggle CodeDiff" },
    },
    config = function(_, opts)
      -- Workaround de neovim/neovim#40290 (adaptado de craftzdog/dotfiles@c6bad80,
      -- config/workarounds.lua): o autocmd OptionSet "Refresh treesitter folds"
      -- de vim/treesitter/_fold.lua percorre todos os buffers sem checar se
      -- ainda são válidos, e o modo compact do codediff, que muda 'foldminlines'
      -- a cada arquivo, quebra com "Invalid buffer id" quando um buffer do diff
      -- já foi apagado. Sem esse autocmd só se perde o refresh ao mudar
      -- 'foldminlines'/'foldnestmax'. Remover quando o Neovim instalado trouxer
      -- a correção (a issue foi fechada em 2026-10-21; o 0.12.2 ainda tem o código).
      pcall(function()
        require("vim.treesitter._fold")
        for _, au in ipairs(vim.api.nvim_get_autocmds({ event = "OptionSet" })) do
          if au.desc == "Refresh treesitter folds" then
            vim.api.nvim_del_autocmd(au.id)
          end
        end
      end)

      require("codediff").setup(opts)
    end,
    opts = {
      explorer = {
        width = 50,
        auto_open_on_cursor = true,
        view_mode = "tree", -- "list" ou "tree"
        line_stats = { enabled = true },
      },
      diff = {
        compact = true,
        compact_context_lines = 8,
        compact_sync_folds = true, -- abre/fecha as dobras nos dois painéis juntos
      },
      keymaps = {
        view = {},
      },
    },
  },
}
