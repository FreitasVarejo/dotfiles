vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

do
  local function prepend_path(p)
    if vim.fn.isdirectory(p) == 1 then
      vim.opt.path:prepend(p)
      vim.env.PATH = p .. ":" .. (vim.env.PATH or "")
    end
  end

  prepend_path(vim.env.HOME .. "/.dotnet")
  prepend_path(vim.env.HOME .. "/.dotnet/tools")

  if vim.fn.isdirectory(vim.env.HOME .. "/.dotnet") == 1 then
    vim.env.DOTNET_ROOT = vim.env.HOME .. "/.dotnet"
  end

  local nvm_alias = vim.env.HOME .. "/.nvm/alias/default"
  if vim.fn.filereadable(nvm_alias) == 1 then
    local ver = vim.fn.trim(vim.fn.readfile(nvm_alias)[1])
    local nvm_dir = string.match(ver, "^v(.+)")
    if nvm_dir then
      local latest = nil
      local latest_path = nil
      for _, dir in ipairs(vim.fn.glob(vim.env.HOME .. "/.nvm/versions/node/v" .. nvm_dir .. "*", false, true)) do
        if not latest or dir > latest then
          latest = dir
          latest_path = dir .. "/bin"
        end
      end
      if latest_path then
        prepend_path(latest_path)
      end
    end
  end
end

require("config.lazy")