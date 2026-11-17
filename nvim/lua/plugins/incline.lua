-- Nome do arquivo flutuando no canto de cada janela.
-- Adaptado de craftzdog/dotfiles@c6bad80 (plugins/ui.lua, bloco incline).
return {
  {
    "b0o/incline.nvim",
    -- VeryLazy: já aparece nos splits abertos na partida.
    event = "VeryLazy",
    opts = {
      window = {
        margin = { vertical = 0, horizontal = 1 },
        zindex = 10,
      },
      hide = {
        cursorline = "smart",
      },
      render = function(props)
        local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ":t")
        if vim.bo[props.buf].modified then
          filename = "[+] " .. filename
        end

        -- O ícone vem do mini.icons que o LazyVim já traz; sem ele, só o nome.
        local ok, mini_icons = pcall(require, "mini.icons")
        if not ok then
          return { { filename } }
        end
        local icon, hl = mini_icons.get("file", filename)
        return { { icon, group = hl }, { " " }, { filename } }
      end,
    },
  },
}
