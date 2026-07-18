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

  vim.env.NVM_DIR = vim.env.NVM_DIR or (vim.env.HOME .. "/.nvm")
  local nvm_alias = vim.env.NVM_DIR .. "/alias/default"
  if vim.fn.filereadable(nvm_alias) == 1 then
    local ver = vim.fn.trim(vim.fn.readfile(nvm_alias)[1])
    local major_minor = string.match(ver, "^v(%d+%.%d+)")
    if major_minor then
      local candidates = vim.fn.glob(vim.env.NVM_DIR .. "/versions/node/v" .. major_minor .. ".*", false, true)
      local function key(s)
        return s:gsub("v?(%d+)%.(%d+)%.(%d+)", function(a, b, c)
          return string.format("%03d.%03d.%03d", tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0)
        end)
      end
      table.sort(candidates, function(a, b)
        return key(a) < key(b)
      end)
      if #candidates > 0 then
        prepend_path(candidates[#candidates] .. "/bin")
      end
    end
  end
end

require("config.lazy")