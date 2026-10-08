vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

do
  local function prepend_path(p)
    if vim.fn.isdirectory(p) ~= 1 then
      return
    end
    local sep = ":"
    local current = vim.env.PATH or ""
    for segment in string.gmatch(current, "([^" .. sep .. "]+)") do
      if segment == p then
        return
      end
    end
    vim.env.PATH = p .. sep .. current
  end

  prepend_path(vim.env.HOME .. "/.dotnet")
  prepend_path(vim.env.HOME .. "/.dotnet/tools")

  if vim.fn.isdirectory(vim.env.HOME .. "/.dotnet") == 1 then
    vim.env.DOTNET_ROOT = vim.env.HOME .. "/.dotnet"
  end

  -- Node do nvm para o vtsls/eslint, sem depender do shell ter carregado o
  -- nvm. alias/default pode ser uma versão (v22.3.0, 22) ou outro alias
  -- (lts/krypton, que é um arquivo em alias/ com a versão); segue a cadeia e,
  -- se nada casar com uma versão instalada, usa a mais nova instalada.
  vim.env.NVM_DIR = vim.env.NVM_DIR or (vim.env.HOME .. "/.nvm")
  local installed = vim.fn.glob(vim.env.NVM_DIR .. "/versions/node/v*", false, true)
  local function key(s)
    return (s:gsub("v?(%d+)%.(%d+)%.(%d+)", function(a, b, c)
      return string.format("%03d.%03d.%03d", tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0)
    end))
  end
  table.sort(installed, function(a, b)
    return key(a) < key(b)
  end)

  local function newest_matching(prefix)
    for i = #installed, 1, -1 do
      local ver = vim.fs.basename(installed[i]):sub(2)
      if ver == prefix or vim.startswith(ver, prefix .. ".") then
        return installed[i]
      end
    end
  end

  local function resolve(alias, depth)
    local file = vim.env.NVM_DIR .. "/alias/" .. alias
    if depth > 5 or vim.fn.filereadable(file) ~= 1 then
      return nil
    end
    local target = vim.trim(vim.fn.readfile(file)[1] or "")
    local prefix = target:match("^v?(%d[%d%.]*)$")
    if prefix then
      return newest_matching(prefix)
    end
    return resolve(target, depth + 1)
  end

  local node_dir = resolve("default", 0) or installed[#installed]
  if node_dir then
    prepend_path(node_dir .. "/bin")
  end
end

require("config.lazy")