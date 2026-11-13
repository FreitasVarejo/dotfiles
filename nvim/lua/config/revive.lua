-- Restauração do nvim depois de uma queda do tmux (contrato @revive, em
-- tmux/scripts/snapshot). Cada nvim dentro de um pane grava a PRÓPRIA sessão
-- (um arquivo por nvim, não o do persistence.nvim, que é por cwd) e o shada, e
-- diz ao tmux que `nvim -S <arquivo>` o reabre. O que não foi salvo com :w
-- volta pelo swap (E325 pede Recover).

if not vim.env.TMUX_PANE or vim.fn.executable("tmux") == 0 then
  return
end

local pane = vim.env.TMUX_PANE
local dir = (vim.env.XDG_DATA_HOME or (vim.env.HOME .. "/.local/share")) .. "/tmux/revive/nvim"
vim.fn.mkdir(dir, "p")

-- Sessões de nvim que morreram há tempo não servem a nenhum snapshot.
local function prune()
  local limit = os.time() - 14 * 24 * 3600
  local handle = vim.uv.fs_scandir(dir)
  while handle do
    local name = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end
    local stat = vim.uv.fs_stat(dir .. "/" .. name)
    if stat and stat.mtime.sec < limit then
      vim.uv.fs_unlink(dir .. "/" .. name)
    end
  end
end

-- Aberto com `-S <arquivo nosso>` (restauração): continua no mesmo arquivo.
local file
for i, arg in ipairs(vim.v.argv) do
  if arg == "-S" and vim.v.argv[i + 1] then
    local path = vim.fn.fnamemodify(vim.v.argv[i + 1], ":p")
    if vim.startswith(path, dir .. "/") then
      file = path
    end
  end
end
file = file or string.format("%s/%d-%d.vim", dir, os.time(), vim.uv.os_getpid())

local function tmux_revive(value)
  local cmd = { "tmux", "set", "-p", "-t", pane, "@revive" }
  if value then
    table.insert(cmd, value)
  else
    table.insert(cmd, 3, "-u")
  end
  vim.system(cmd, {}):wait()
end

-- Um programa que roda dentro do pane (o claude abrindo o nvim como editor)
-- tinha o @revive dele; ao sair devolvemos o que estava lá.
local previous
local registered = false
local enabled = false

local function save()
  if not enabled then
    return
  end
  local tmp = file .. ".tmp"
  if not pcall(vim.cmd, "silent! mksession! " .. vim.fn.fnameescape(tmp)) then
    return
  end
  vim.v.this_session = file
  -- rename atômico: um nvim que ainda está dando `source` no arquivo antigo
  -- (restauração em curso) continua lendo o inode antigo.
  vim.uv.fs_rename(tmp, file)
  pcall(vim.cmd, "silent! wshada")
  if not registered then
    registered = true
    local r = vim.system({ "tmux", "show", "-pv", "-t", pane, "@revive" }, { text = true }):wait()
    previous = r.code == 0 and vim.trim(r.stdout or "") or ""
    tmux_revive("nvim -S " .. vim.fn.shellescape(file))
  end
end

local timer = vim.uv.new_timer()
local function schedule()
  timer:stop()
  timer:start(1500, 0, vim.schedule_wrap(save))
end

local group = vim.api.nvim_create_augroup("tmux_revive", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "WinNew", "WinClosed", "FocusLost" }, {
  group = group,
  callback = schedule,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = group,
  callback = function()
    enabled = false
    timer:stop()
    if registered then
      tmux_revive(previous ~= "" and previous or nil)
    end
  end,
})

-- Só depois de a sessão restaurada terminar de carregar, para não gravar por
-- cima dela no meio do `source`.
vim.defer_fn(function()
  enabled = true
  prune()
  save()
  local periodic = vim.uv.new_timer()
  periodic:start(120000, 120000, vim.schedule_wrap(save))
end, 3000)
