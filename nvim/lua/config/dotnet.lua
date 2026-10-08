-- Solution de trabalho de um buffer C#, para build/run/test/debug não
-- dependerem do cwd (o Yazi muda o cwd ao fechar, e a raiz de um monorepo
-- .NET costuma não ter solution).
local M = {}

local skip_dirs = { bin = true, obj = true, node_modules = true }

--- A solution que o roslyn.nvim travou (<leader>rt), se o arquivo existe;
--- senão a .sln/.slnx/.slnf mais próxima subindo a partir do buffer.
---@param bufnr? integer
---@return string?
function M.solution(bufnr)
  local locked = vim.g.roslyn_nvim_selected_solution
  if locked and vim.uv.fs_stat(locked) then
    return locked
  end
  local name = vim.api.nvim_buf_get_name(bufnr or 0)
  return vim.fs.find(function(n)
    return n:match("%.slnx?$") ~= nil or n:match("%.slnf$") ~= nil
  end, {
    path = name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd(),
    upward = true,
    type = "file",
    limit = 1,
  })[1]
end

--- *.Host.csproj debaixo do diretório da solution.
---@param sln string
---@return string[]
function M.host_projects(sln)
  local dir = vim.fs.dirname(sln)
  local found = {}
  for name, type in
    vim.fs.dir(dir, {
      depth = 8,
      skip = function(d)
        local base = vim.fs.basename(d)
        return not skip_dirs[base] and not vim.startswith(base, ".")
      end,
    })
  do
    if type == "file" and name:match("%.Host%.csproj$") then
      found[#found + 1] = vim.fs.joinpath(dir, name)
    end
  end
  return found
end

--- *.Host.dll de Debug debaixo do diretório da solution.
---@param sln string
---@return string[]
function M.host_dlls(sln)
  return vim.fn.globpath(vim.fs.dirname(sln), "**/bin/Debug/*/*.Host.dll", false, true)
end

local function bang(cmd)
  vim.cmd("!" .. cmd)
end

--- `dotnet <verb>` na solution do buffer; sem solution, no cwd como antes.
---@param verb "build"|"test"|"clean"
function M.solution_cmd(verb)
  local sln = M.solution()
  bang("dotnet " .. verb .. (sln and " " .. vim.fn.shellescape(sln, true) or ""))
end

--- `dotnet run` não aceita solution com vários projetos: roda o *.Host.csproj
--- dela (escolhe se houver mais de um).
function M.run()
  local sln = M.solution()
  if not sln then
    return bang("dotnet run")
  end
  local hosts = M.host_projects(sln)
  local function run(csproj)
    bang("dotnet run --project " .. vim.fn.shellescape(csproj, true))
  end
  if #hosts == 0 then
    vim.notify("Nenhum *.Host.csproj debaixo de " .. vim.fs.dirname(sln), vim.log.levels.WARN)
  elseif #hosts == 1 then
    run(hosts[1])
  else
    vim.ui.select(hosts, { prompt = "Host" }, function(choice)
      if choice then
        run(choice)
      end
    end)
  end
end

--- Build/run/test/clean no <localleader> do buffer: as teclas <leader>c* são
--- do LazyVim, que no LspAttach põe Rename e Run Codelens buffer-local por
--- cima de qualquer mapeamento global.
---@param bufnr integer
function M.keymaps(bufnr)
  local function map(lhs, fn, desc)
    vim.keymap.set("n", "<localleader>" .. lhs, fn, { buffer = bufnr, desc = desc })
  end
  map("b", function()
    M.solution_cmd("build")
  end, "dotnet build (solution)")
  map("r", M.run, "dotnet run (*.Host)")
  map("t", function()
    M.solution_cmd("test")
  end, "dotnet test (solution)")
  map("c", function()
    M.solution_cmd("clean")
  end, "dotnet clean (solution)")
end

return M
