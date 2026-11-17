return {
  {
    "neovim/nvim-lspconfig",
    -- Soma o código do diagnóstico à mensagem do virtual text. Só `opts.diagnostics`
    -- é tocado: spacing, source e prefix continuam os do LazyVim. A fonte não
    -- entra aqui porque o Neovim já a prefixa (source = "if_many") depois do format.
    -- Adaptado de craftzdog/dotfiles@c6bad80 (config de vim.diagnostic, plugins/ui.lua).
    opts = function(_, opts)
      opts.diagnostics = opts.diagnostics or {}
      local virtual_text = opts.diagnostics.virtual_text
      if type(virtual_text) ~= "table" then
        return
      end
      virtual_text.format = function(diagnostic)
        if diagnostic.code then
          return string.format("%s [%s]", diagnostic.message, tostring(diagnostic.code))
        end
        return diagnostic.message
      end
    end,
  },
}
