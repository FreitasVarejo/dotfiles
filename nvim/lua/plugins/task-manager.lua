-- Task Manager: Obsidian-backed task tracking driven by Snacks.picker.
--
-- Operates exclusively under ~/ObsidianVault/tasks/. Each project is a
-- subdirectory (kebab-case id) and each task is a markdown file whose first
-- line encodes its status callout, e.g. `> [!todo] 1 - Backlog`.
--
-- The UI is a two-level Snacks picker:
--   Level 1 (<leader>ob): projects
--   Level 2 (from a project): tasks, grouped by status
--
-- Note: this only touches plain files + Snacks + vim.ui, so it does not use
-- obsidian.nvim's API (obsidian.nvim is configured separately in obsidian.lua
-- for note editing). It is declared as an `optional` fragment of the
-- already-configured snacks.nvim spec.

local M = {}

local root = vim.fn.expand("~/ObsidianVault/tasks")

-- Default status metadata, mirrored to tasks/status.json on first use and used
-- as the fallback when that file is missing or unparsable.
local DEFAULT_STATUS_JSON = [[{
  "1": { "title": "Backlog", "callout": "todo", "icon": "", "hl_group": "DiagnosticInfo" },
  "2": { "title": "In Progress", "callout": "example", "icon": "", "hl_group": "DiagnosticHint" },
  "3": { "title": "Blocked", "callout": "warning", "icon": "󰂃", "hl_group": "DiagnosticWarn" },
  "4": { "title": "Review", "callout": "question", "icon": "󰋗", "hl_group": "DiagnosticVirtualTextInfo" },
  "5": { "title": "Done", "callout": "success", "icon": "", "hl_group": "DiagnosticOk" }
}]]

-- Multibyte-safe accent folding for kebab-case ids (handles PT-BR titles).
local ACCENTS = {
  ["á"] = "a",
  ["à"] = "a",
  ["â"] = "a",
  ["ã"] = "a",
  ["ä"] = "a",
  ["é"] = "e",
  ["ê"] = "e",
  ["è"] = "e",
  ["ë"] = "e",
  ["í"] = "i",
  ["ì"] = "i",
  ["î"] = "i",
  ["ï"] = "i",
  ["ó"] = "o",
  ["ô"] = "o",
  ["õ"] = "o",
  ["ò"] = "o",
  ["ö"] = "o",
  ["ú"] = "u",
  ["ù"] = "u",
  ["û"] = "u",
  ["ü"] = "u",
  ["ç"] = "c",
  ["ñ"] = "n",
}

---Convert an arbitrary string to a kebab-case identifier.
---@param s string
---@return string
local function kebab(s)
  s = s:lower()
  for from, to in pairs(ACCENTS) do
    s = s:gsub(from, to)
  end
  s = s:gsub("[^%w%s%-]", "") -- drop anything that is not word/space/dash
  s = s:gsub("[%s_]+", "-") -- whitespace and underscores become dashes
  s = s:gsub("%-+", "-") -- collapse repeated dashes
  s = s:gsub("^%-+", ""):gsub("%-+$", "") -- trim leading/trailing dashes
  return s
end

--- State ---------------------------------------------------------------------

M.status = nil ---@type table<string, table>|nil
M.cache = nil ---@type table[]|nil

---Ensure the tasks root and status.json exist.
function M.ensure_root()
  if vim.fn.isdirectory(root) == 0 then
    vim.fn.mkdir(root, "p")
  end
  local sj = root .. "/status.json"
  if vim.fn.filereadable(sj) == 0 then
    vim.fn.writefile(vim.split(DEFAULT_STATUS_JSON, "\n"), sj)
  end
end

---Load status metadata from tasks/status.json (falls back to defaults).
function M.load_status()
  local sj = root .. "/status.json"
  if vim.fn.filereadable(sj) == 1 then
    local ok, decoded = pcall(function()
      return vim.json.decode(table.concat(vim.fn.readfile(sj), "\n"))
    end)
    if ok and type(decoded) == "table" then
      M.status = decoded
      return
    end
    vim.notify("task-manager: could not parse status.json, using defaults", vim.log.levels.WARN)
  end
  M.status = vim.json.decode(DEFAULT_STATUS_JSON)
end

---Read only the first line of a task file and extract its status number.
---@param path string
---@return integer|nil
function M.parse_status_num(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local first = f:read("*l")
  f:close()
  if not first then
    return nil
  end
  local num = first:match(">%s*%[!%w+%]%s*(%d+)")
  return num and tonumber(num) or nil
end

--- Cache ---------------------------------------------------------------------

---Insert or update a single task in the in-memory cache.
---@param path string
function M.update_cache_entry(path)
  local project, task_id = path:match(".*/tasks/([^/]+)/([^/]+)%.md$")
  if not project then
    return
  end
  M.cache = M.cache or {}
  local num = M.parse_status_num(path) or 1
  for _, e in ipairs(M.cache) do
    if e.path == path then
      e.status_num = num
      return
    end
  end
  M.cache[#M.cache + 1] = { project = project, task_id = task_id, status_num = num, path = path }
end

---Drop a task from the cache (after deletion).
---@param path string
function M.remove_cache_entry(path)
  if not M.cache then
    return
  end
  for i, e in ipairs(M.cache) do
    if e.path == path then
      table.remove(M.cache, i)
      return
    end
  end
end

---Full rescan of tasks/*/*.md into the cache.
function M.build_cache()
  M.cache = {}
  for _, path in ipairs(vim.fn.glob(root .. "/*/*.md", true, true)) do
    M.update_cache_entry(path)
  end
end

---Cached tasks for a project, sorted ascending by status then id.
---@param project string
---@return table[]
function M.entries_for(project)
  local list = {}
  for _, e in ipairs(M.cache or {}) do
    if e.project == project then
      list[#list + 1] = e
    end
  end
  table.sort(list, function(a, b)
    if a.status_num == b.status_num then
      return a.task_id < b.task_id
    end
    return a.status_num < b.status_num
  end)
  return list
end

---List project ids (subdirectories of the tasks root).
---@return string[]
function M.list_projects()
  local out = {}
  for _, path in ipairs(vim.fn.glob(root .. "/*", true, true)) do
    if vim.fn.isdirectory(path) == 1 then
      out[#out + 1] = vim.fn.fnamemodify(path, ":t")
    end
  end
  table.sort(out)
  return out
end

--- File operations -----------------------------------------------------------

---Build the markdown template for a new task.
---@param title string original (un-slugified) task title
---@param task_id string kebab-case id
---@param project string project id
---@return string[]
function M.template(title, task_id, project)
  local st = (M.status and M.status["1"]) or { callout = "todo", title = "Backlog" }
  return {
    string.format("> [!%s] 1 - %s", st.callout or "todo", st.title or "Backlog"),
    string.format("> **%s** - [[%s]]", title, task_id),
    string.format("> Branch: `feat/%s`", task_id),
    "> Impedimentos: ",
    "",
    "## Notas Soltas",
    "- ",
    "",
    "### [" .. project .. "]",
    "- [ ] ",
  }
end

---Rewrite the status callout on the first line of a task file, in place.
---Prefers editing a loaded buffer so open windows stay in sync.
---@param path string
---@param num string|integer status key
function M.write_first_line(path, num)
  local st = M.status and M.status[tostring(num)]
  if not st then
    return
  end
  local newline = string.format("> [!%s] %s - %s", st.callout or "note", num, st.title or "")
  local buf = vim.fn.bufnr(path)
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    vim.api.nvim_buf_set_lines(buf, 0, 1, false, { newline })
    vim.api.nvim_buf_call(buf, function()
      vim.cmd("silent keepjumps write")
    end)
  else
    local lines = vim.fn.readfile(path)
    if #lines == 0 then
      lines = { newline }
    else
      lines[1] = newline
    end
    vim.fn.writefile(lines, path)
  end
end

--- CURRENT.md dashboard ------------------------------------------------------

---Read the leading callout block (the contiguous `>` lines) of a task file.
---@param path string
---@return string[]
function M.read_callout(path)
  local out = {}
  local f = io.open(path, "r")
  if not f then
    return out
  end
  for line in f:lines() do
    if line:match("^%s*>") then
      out[#out + 1] = line
    elseif #out > 0 then
      break -- callout block ended
    elseif not line:match("^%s*$") then
      break -- hit non-blank, non-callout before any callout
    end
  end
  f:close()
  return out
end

---Extract the user-authored body of the `## Notas Avulsas` section so it can
---be preserved across dashboard regenerations.
---@param path string
---@return string[]
function M.extract_loose_notes(path)
  if vim.fn.filereadable(path) == 0 then
    return {}
  end
  local out, capturing = {}, false
  for _, l in ipairs(vim.fn.readfile(path)) do
    if l:match("^##%s+Notas Avulsas") then
      capturing = true
    elseif capturing and l:match("^##%s+") then
      break -- next section starts
    elseif capturing then
      out[#out + 1] = l
    end
  end
  while #out > 0 and out[1]:match("^%s*$") do
    table.remove(out, 1)
  end
  while #out > 0 and out[#out]:match("^%s*$") do
    table.remove(out)
  end
  if #out == 1 and out[1]:match("^%-%s*$") then
    out = {} -- drop the lone placeholder bullet
  end
  return out
end

---Regenerate tasks/CURRENT.md: header, preserved `## Notas Avulsas`, then one
---`## <project>` section per project with each task's callout block. Preserves
---unsaved edits by refusing to overwrite a modified CURRENT.md buffer.
function M.rebuild_current()
  M.ensure_root()
  M.load_status()
  M.build_cache()
  local path = root .. "/CURRENT.md"
  local buf = vim.fn.bufnr(path)
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
    vim.notify("task-manager: CURRENT.md has unsaved changes; skipping regen", vim.log.levels.WARN)
    return
  end

  local notes = M.extract_loose_notes(path)
  local projects = M.list_projects()
  local total = #(M.cache or {})

  local lines = {
    "# CURRENT",
    "",
    string.format("> Painel gerado automaticamente — %d tasks em %d projetos.", total, #projects),
    "> Abra o gestor com `<leader>ob`; regenere este painel com `<C-a>`.",
    "",
    "## Notas Avulsas",
    "",
  }
  if #notes == 0 then
    lines[#lines + 1] = "- "
  else
    for _, l in ipairs(notes) do
      lines[#lines + 1] = l
    end
  end
  lines[#lines + 1] = ""

  for _, project in ipairs(projects) do
    lines[#lines + 1] = "## " .. project
    lines[#lines + 1] = ""
    local entries = M.entries_for(project)
    if #entries == 0 then
      lines[#lines + 1] = "_(sem tasks)_"
      lines[#lines + 1] = ""
    else
      for _, e in ipairs(entries) do
        for _, cl in ipairs(M.read_callout(e.path)) do
          lines[#lines + 1] = cl
        end
        lines[#lines + 1] = ""
      end
    end
  end

  vim.fn.writefile(lines, path)
  -- If the dashboard is open, reload it so the regen is visible immediately.
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    vim.api.nvim_buf_call(buf, function()
      vim.cmd("silent edit!")
    end)
  end
end

--- Pickers -------------------------------------------------------------------

---Level 2: tasks of a single project.
---@param project string
function M.open_tasks(project)
  M.ensure_root()
  M.load_status()
  Snacks.picker.pick({
    source = "obsidian_tasks",
    title = "Tasks: " .. project .. "   ⏎ open · C-t new · C-x del · C-e status · C-o back · ? help",
    -- Keep the picker open on an empty project so <C-t> can add the first task.
    show_empty = true,
    finder = function()
      local items = {}
      for _, e in ipairs(M.entries_for(project)) do
        items[#items + 1] = { text = e.task_id, file = e.path, entry = e }
      end
      return items
    end,
    format = function(item)
      local e = item.entry
      local st = (M.status and M.status[tostring(e.status_num)]) or {}
      local hl = st.hl_group or "Normal"
      return {
        { (st.icon or "") .. " ", hl },
        { st.title or ("Status " .. tostring(e.status_num)), hl },
        { " - ", "SnacksPickerDelim" },
        { e.task_id, "SnacksPickerLabel" },
      }
    end,
    confirm = function(picker, item)
      if not item then
        return
      end
      picker:close()
      vim.schedule(function()
        vim.cmd.edit(vim.fn.fnameescape(item.file))
      end)
    end,
    actions = {
      -- <C-t>: create a new task from a title prompt.
      new_task = function(picker)
        vim.ui.input({ prompt = "New task title: " }, function(input)
          if not input or input == "" then
            return
          end
          local id = kebab(input)
          if id == "" then
            vim.notify("task-manager: invalid task title", vim.log.levels.WARN)
            return
          end
          local path = root .. "/" .. project .. "/" .. id .. ".md"
          if vim.fn.filereadable(path) == 1 then
            vim.notify("task-manager: task already exists: " .. id, vim.log.levels.WARN)
            return
          end
          vim.fn.writefile(M.template(input, id, project), path)
          M.update_cache_entry(path)
          picker:close()
          vim.schedule(function()
            vim.cmd.edit(vim.fn.fnameescape(path))
          end)
        end)
      end,
      -- <C-x>: delete the selected task after confirmation.
      delete_task = function(picker, item)
        item = item or picker:current()
        if not item then
          return
        end
        local choice = vim.fn.confirm("Delete task '" .. item.entry.task_id .. "'?", "&Yes\n&No", 2)
        if choice ~= 1 then
          return
        end
        vim.fn.delete(item.file)
        M.remove_cache_entry(item.file)
        picker:find()
      end,
      -- <C-s>: change the selected task's status via a select prompt.
      set_status = function(picker, item)
        item = item or picker:current()
        if not item then
          return
        end
        local keys = vim.tbl_keys(M.status or {})
        table.sort(keys, function(a, b)
          return tonumber(a) < tonumber(b)
        end)
        local choices = {}
        for _, n in ipairs(keys) do
          choices[#choices + 1] = { num = n, label = n .. " - " .. (M.status[n].title or "") }
        end
        vim.ui.select(choices, {
          prompt = "Set status:",
          format_item = function(c)
            return c.label
          end,
        }, function(choice)
          if not choice then
            return
          end
          M.write_first_line(item.file, choice.num)
          M.update_cache_entry(item.file)
          picker:find()
        end)
      end,
      -- <C-o>: go back to the project list (Level 1).
      back_to_projects = function(picker)
        picker:close()
        vim.schedule(function()
          M.open_projects()
        end)
      end,
    },
    win = {
      input = {
        keys = {
          ["<c-t>"] = { "new_task", mode = { "i", "n" }, desc = "New task" },
          ["<c-x>"] = { "delete_task", mode = { "i", "n" }, desc = "Delete task" },
          ["<c-e>"] = { "set_status", mode = { "i", "n" }, desc = "Set status" },
          ["<c-o>"] = { "back_to_projects", mode = { "i", "n" }, desc = "Back to projects" },
        },
      },
    },
  })
end

---Level 1: projects.
function M.open_projects()
  M.ensure_root()
  M.load_status()
  M.build_cache()
  Snacks.picker.pick({
    source = "obsidian_projects",
    title = "Task Projects   ⏎ open · C-c new · C-a CURRENT.md · ? help",
    -- Keep the picker open on a fresh vault so <C-c> can create the first project.
    show_empty = true,
    -- Project items carry no `file`, so hide the preview pane to avoid the
    -- default file previewer's "Item has no `file`" error.
    preview = "none",
    layout = { preview = false },
    finder = function()
      local items = {}
      for _, project in ipairs(M.list_projects()) do
        items[#items + 1] = { text = project, project = project }
      end
      return items
    end,
    format = function(item)
      return {
        { "  ", "SnacksPickerDirectory" },
        { item.project, "SnacksPickerDirectory" },
      }
    end,
    confirm = function(picker, item)
      if not item then
        return
      end
      picker:close()
      vim.schedule(function()
        M.open_tasks(item.project)
      end)
    end,
    actions = {
      -- <C-c>: create a new project directory.
      new_project = function(picker)
        vim.ui.input({ prompt = "New project name: " }, function(input)
          if not input or input == "" then
            return
          end
          local id = kebab(input)
          if id == "" then
            vim.notify("task-manager: invalid project name", vim.log.levels.WARN)
            return
          end
          vim.fn.mkdir(root .. "/" .. id, "p")
          picker:find()
        end)
      end,
      -- <C-a>: regenerate and open the CURRENT.md dashboard.
      open_current = function(picker)
        picker:close()
        vim.schedule(function()
          M.rebuild_current()
          vim.cmd.edit(vim.fn.fnameescape(root .. "/CURRENT.md"))
        end)
      end,
    },
    win = {
      input = {
        keys = {
          ["<c-c>"] = { "new_project", mode = { "i", "n" }, desc = "New project" },
          ["<c-a>"] = { "open_current", mode = { "i", "n" }, desc = "Open CURRENT.md" },
        },
      },
    },
  })
end

---Keep the cache fresh when a task file is written.
function M.setup_autocmd()
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("obsidian_task_manager", { clear = true }),
    pattern = root .. "/*/*.md",
    callback = function(args)
      if M.cache then
        M.update_cache_entry(args.match)
      end
    end,
  })
end

return {
  "folke/snacks.nvim",
  optional = true,
  init = function()
    M.setup_autocmd()
  end,
  keys = {
    {
      "<leader>ob",
      function()
        M.open_projects()
      end,
      desc = "Task Manager (Obsidian)",
    },
  },
}
