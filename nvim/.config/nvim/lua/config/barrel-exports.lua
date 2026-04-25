local function generate_barrel_exports()
  local current_dir = vim.fn.expand("%:p:h")
  local current_file = vim.fn.expand("%:t")

  local uv = vim.uv or vim.loop
  local req = uv.fs_scandir(current_dir)
  if not req then
    vim.notify("Não foi possível ler o diretório", vim.log.levels.ERROR)
    return
  end

  local exports = {}

  while true do
    local name, type = uv.fs_scandir_next(req)
    if not name then
      break
    end

    if name ~= current_file and not name:match("^%.") then
      local basename = name

      if type == "file" or type == "link" then
        basename = name:gsub("%.tsx?$", ""):gsub("%.jsx?$", ""):gsub("%.d%.ts$", "")
      end

      table.insert(exports, string.format('export * from "./%s";', basename))
    end
  end

  if #exports == 0 then
    vim.notify("Nenhum arquivo ou pasta encontrado para exportar.", vim.log.levels.WARN)
    return
  end

  table.sort(exports)

  -- Substitui todo o conteúdo do arquivo
  -- 0 = buffer atual
  -- 0, -1 = da linha 0 (início) até a linha -1 (fim)
  -- false = strict_indexing (sempre false para set_lines)
  -- exports = a tabela com as novas linhas
  vim.api.nvim_buf_set_lines(0, 0, -1, false, exports)

  vim.notify("Exports gerados com sucesso!", vim.log.levels.INFO)
end

vim.api.nvim_create_user_command("GenerateExports", generate_barrel_exports, {})
vim.keymap.set("n", "<leader>cx", generate_barrel_exports, { desc = "Generate Barrel Exports (export *)" })
