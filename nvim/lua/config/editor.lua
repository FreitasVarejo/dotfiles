-- Ajudas de edição ligadas por config/keymaps.lua: copiar referência de
-- arquivo para colar num agente, apagar buffers ocultos e abrir o arquivo como
-- estava no commit do blame.
local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO)
end

--- Linhas da seleção visual atual (ordenadas) ou nil fora do visual. Lê
--- line("v") e line(".") ainda dentro do visual, porque as marcas '< e '> só
--- são atualizadas depois que ele termina.
---@return integer? first
---@return integer? last
local function visual_range()
  if not vim.fn.mode():match("^[vV\22]") then
    return nil
  end
  local a, b = vim.fn.line("v"), vim.fn.line(".")
  return math.min(a, b), math.max(a, b)
end

local function leave_visual()
  vim.cmd("normal! " .. vim.keycode("<Esc>"))
end

--- Copia `caminho#L<linha>` (ou `#L<ini>-L<fim>` no visual) para o clipboard.
--- Adaptado de craftzdog/dotfiles@c6bad80 (lua/craftzdog/utils/editor.lua,
--- yank_*_with_line), com a seleção em várias linhas e o caminho absoluto numa
--- função só.
---@param absolute boolean caminho absoluto (`%:p`) em vez de relativo ao cwd (`%:.`)
function M.yank_path_with_line(absolute)
  local path = vim.fn.expand(absolute and "%:p" or "%:.")
  if path == "" then
    notify("Buffer sem nome de arquivo", vim.log.levels.WARN)
    return
  end
  local first, last = visual_range()
  local suffix
  if first then
    leave_visual()
    suffix = first == last and ("#L" .. first) or ("#L" .. first .. "-L" .. last)
  else
    suffix = "#L" .. vim.fn.line(".")
  end
  local text = path .. suffix
  vim.fn.setreg("+", text)
  notify("Copiado: " .. text)
end

-- O nome que o Markdown espera para o filetype quando difere dele.
local ft_to_lang = {
  typescriptreact = "tsx",
  javascriptreact = "jsx",
  typescript = "ts",
  javascript = "js",
}

--- Copia a seleção como bloco Markdown com o arquivo e a linha inicial no
--- cabeçalho da cerca. Só no visual.
--- Adaptado de craftzdog/dotfiles@c6bad80 (lua/craftzdog/utils/editor.lua,
--- copy_as_codeblock).
function M.copy_as_codeblock()
  local first, last = visual_range()
  if not first then
    return
  end
  leave_visual()

  local filepath = vim.api.nvim_buf_get_name(0)
  if filepath == "" then
    notify("Buffer sem nome de arquivo", vim.log.levels.WARN)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
  local lang = ft_to_lang[vim.bo.filetype] or vim.bo.filetype
  local relative = vim.fn.fnamemodify(filepath, ":.")

  local result = { "```" .. lang .. ' filename="' .. relative .. '" line=' .. first }
  vim.list_extend(result, lines)
  table.insert(result, "```")

  vim.fn.setreg("+", table.concat(result, "\n"))
  notify("Copiadas " .. #lines .. " linhas como bloco de código")
end

--- Apaga os buffers listados que não estão em nenhuma janela (de nenhuma aba).
--- Os modificados ficam; terminal, quickfix e help (buftype ~= "") também, e
--- cada apagamento está num pcall para uma falha não interromper o laço.
--- Adaptado de craftzdog/dotfiles@c6bad80 (lua/craftzdog/utils/editor.lua,
--- delete_hidden_buffers).
function M.delete_hidden_buffers()
  local visible = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    visible[vim.api.nvim_win_get_buf(win)] = true
  end

  local deleted, skipped = 0, 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and not visible[buf] and vim.bo[buf].buftype == "" then
      if vim.bo[buf].modified then
        skipped = skipped + 1
      elseif pcall(vim.api.nvim_buf_delete, buf, {}) then
        deleted = deleted + 1
      end
    end
  end

  local msg = deleted .. " apagados"
  if skipped > 0 then
    msg = msg .. " (" .. skipped .. " pulados por alteração não salva)"
  end
  notify(msg)
end

--- Abre, numa aba nova, o arquivo como estava no commit do blame da linha do
--- cursor, na linha que ela tinha lá. Usa internals do gitsigns (async, cache,
--- actions/diffthis), que mudam sem aviso: qualquer falha vira aviso.
--- Adaptado de craftzdog/dotfiles@c6bad80 (lua/plugins/keymaps.lua, <leader>go).
function M.open_blamed_file()
  local ok, async = pcall(require, "gitsigns.async")
  local ok_cache, cache = pcall(require, "gitsigns.cache")
  local ok_show, diffthis = pcall(require, "gitsigns.actions.diffthis")
  if not (ok and ok_cache and ok_show) then
    notify("gitsigns indisponível: não dá para abrir o commit do blame", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]

  local function run()
    local bcache = cache.cache[bufnr]
    if not bcache then
      notify("Buffer sem git (gitsigns não anexado)", vim.log.levels.WARN)
      return
    end

    local info = bcache:get_blame(lnum)
    if not info then
      notify("Sem blame para esta linha", vim.log.levels.WARN)
      return
    end

    local sha = info.commit.sha
    -- sha só de zeros: a linha ainda não foi commitada.
    if tonumber("0x" .. sha:sub(1, 8)) == 0 then
      notify("Linha ainda não commitada", vim.log.levels.WARN)
      return
    end

    vim.cmd.tabnew()
    diffthis.show(bufnr, sha, info.filename)
    async.schedule()
    pcall(vim.api.nvim_win_set_cursor, 0, { info.orig_lnum or lnum, 0 })
  end

  async.run(function()
    local ok_run, err = pcall(run)
    if not ok_run then
      notify("Falha ao abrir o commit do blame: " .. tostring(err), vim.log.levels.WARN)
    end
  end)
end

return M
