-- Custom commands for Neovim 0.12+
-- LSP Status command (replacement for deprecated :LspInfo)
vim.api.nvim_create_user_command("LspStatus", function()
  local clients = vim.lsp.get_clients()
  local buf = vim.api.nvim_get_current_buf()
  local buf_clients = vim.lsp.get_clients({ bufnr = buf })

  if #clients == 0 then
    vim.notify("❌ Nenhum cliente LSP ativo", vim.log.levels.WARN)
    return
  end

  local msg = "📊 Status do LSP:\n\n"
  msg = msg .. "Cliente(s) Global(is):\n"

  for _, client in ipairs(clients) do
    local status = client.attached_buffers and next(client.attached_buffers) and "✓" or "○"
    msg = msg .. string.format("  %s %s (id: %d)\n", status, client.name, client.id)
  end

  msg = msg .. "\nCliente(s) para Buffer Atual:\n"
  if #buf_clients == 0 then
    msg = msg .. "  Nenhum cliente ativo para este buffer\n"
  else
    for _, client in ipairs(buf_clients) do
      msg = msg .. string.format("  ✓ %s\n", client.name)
    end
  end

  print(msg)
end, {})

-- Diagnostic toggle command
vim.api.nvim_create_user_command("DiagToggle", function()
  if vim.diagnostic.is_disabled() then
    vim.diagnostic.enable()
    vim.notify("✓ Diagnósticos habilitados", vim.log.levels.INFO)
  else
    vim.diagnostic.disable()
    vim.notify("✗ Diagnósticos desabilitados", vim.log.levels.INFO)
  end
end, {})

-- Show buffer diagnostics
vim.api.nvim_create_user_command("DiagShow", function()
  local diagnostics = vim.diagnostic.get(0)
  if #diagnostics == 0 then
    vim.notify("✓ Nenhum diagnóstico neste buffer", vim.log.levels.INFO)
    return
  end

  local msg = "📋 Diagnósticos do Buffer:\n\n"
  for _, diag in ipairs(diagnostics) do
    local severity = vim.diagnostic.severity[diag.severity]
    msg = msg .. string.format("[%s] Linha %d: %s\n", severity, diag.lnum + 1, diag.message)
  end

  print(msg)
end, {})
