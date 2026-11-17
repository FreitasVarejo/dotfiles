-- Lazygit: o `e` abre o arquivo na janela de onde o lazygit foi aberto (ver
-- o comentário de plugins/ui.lua, que monta o os.edit com estas funções).
-- Adaptado de craftzdog/dotfiles@c6bad80 (lua/craftzdog/utils/lazygit.lua).
local M = {}

-- Janela de origem do último lazygit aberto.
local origin_win = nil

--- Abre o lazygit guardando a janela atual como destino dos arquivos que ele
--- abrir. Repassa os argumentos ao Snacks.lazygit.
---@param opts? snacks.lazygit.Config
function M.open(opts)
  origin_win = vim.api.nvim_get_current_win()
  Snacks.lazygit(opts)
end

--- Foca a janela de origem (e sai do modo terminal do float, o que o `<Cmd>`
--- do --remote-send faz ao rodar em qualquer modo). Sem efeito se a janela foi
--- fechada com o lazygit aberto: o `--remote` seguinte usa a janela atual.
function M.focus_origin()
  if origin_win and vim.api.nvim_win_is_valid(origin_win) then
    pcall(vim.api.nvim_set_current_win, origin_win)
  end
  vim.cmd.stopinsert()
end

-- $NVIM é o socket RPC do Neovim que abriu o lazygit.
local server = 'nvim --server "$NVIM"'

--- Comando os.edit/os.editAtLine em POSIX sh. Sem $NVIM o lazygit foi aberto
--- fora do Neovim e o arquivo abre direto. Com $NVIM: fecha o lazygit (`q`),
--- volta à janela de origem, abre o arquivo ali e, com `at_line`, vai à linha
--- (o `:{{line}}` roda depois de sair do modo terminal, onde o cursor se mantém).
--- O lazygit preenche {{filename}} (já entre aspas) e {{line}}.
---@param opts? { at_line?: boolean }
---@return string
function M.edit_command(opts)
  local at_line = opts and opts.at_line

  local outside = at_line and "nvim +{{line}} -- {{filename}}" or "nvim -- {{filename}}"

  local inside = {
    server .. " --remote-send 'q'",
    server .. [[ --remote-send '<Cmd>lua require("config.lazygit").focus_origin()<CR>']],
    server .. " --remote {{filename}}",
  }
  if at_line then
    table.insert(inside, server .. " --remote-send ':{{line}}<CR>'")
  end

  return ('if [ -z "$NVIM" ]; then %s; else %s; fi'):format(outside, table.concat(inside, " && "))
end

return M
