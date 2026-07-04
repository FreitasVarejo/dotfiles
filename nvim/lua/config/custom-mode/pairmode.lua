local M = {}

M.enabled = false

function M.toggle()
  M.enabled = not M.enabled
  if M.enabled then
    M.enable()
  else
    M.disable()
  end
end

function M.enable()
  vim.opt.relativenumber = false
  vim.notify("Pair Coding Mode ON 👥", vim.log.levels.INFO, {
    icon = "👥",
    id = "pair_mode",
  })
end

function M.disable()
  vim.opt.relativenumber = true
  vim.notify("Pair Coding Mode OFF 👥", vim.log.levels.INFO, {
    icon = "👥",
    id = "pair_mode",
  })
end

return M
