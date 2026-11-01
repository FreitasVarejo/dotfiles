-- obsidian.nvim — notes/vault integration for ~/ObsidianVault.
--
-- UI rendering is delegated to render-markdown.nvim (see lang/markdown.lua),
-- so obsidian's own `ui` layer is disabled to avoid double-rendering callouts
-- and checkboxes. Completion is provided by the built-in obsidian-ls LSP
-- server (the `completion` opts were removed in obsidian.nvim 3.x+).
--
-- obsidian.nvim ships no <leader> mappings of its own (only `:Obsidian <sub>`
-- ex-commands), which is why <leader>o showed nothing before. The keys below
-- surface the common subcommands; note-scoped ones (links, backlinks, rename,
-- toggle_checkbox, template) act on the current note buffer.
--
-- The vault contract (~/ObsidianVault/AGENTS.md) closes the vault root and
-- reserves `tasks/`, `decisoes/` and `daily/`, but the plugin's default
-- (`new_notes_location = "current_dir"`) drops a new note next to the buffer
-- you are in, which from a task lands it inside `tasks/`. `note_folder` below
-- puts it at the project root instead, or in `inbox/` when the buffer is in no
-- project. The daily-note keys are gone for the
-- same reason: `daily/` holds generated snapshots, and with no
-- `daily_notes.folder` the plugin would write today's note in the vault root.
-- `daily_notes.enabled = false` only hides `today`, `yesterday`, `tomorrow`
-- and `dailies` from the `:Obsidian` menu and completion; typing
-- `:Obsidian today` by hand still creates that file.
local vault = vim.fs.normalize("~/ObsidianVault")

-- Provisional name for a note created with no title: six characters of
-- Crockford's base32 in lowercase (no i, l, o or u, which read as 1 and 0).
-- `vim.uv.random` and not `math.random`, which repeats the same sequence in
-- every Neovim session. 16 and 32 divide 256, so a byte modulo either has no
-- bias. The first character is always a letter: the plugin writes the title
-- into `aliases` through `tonumber`, so "000123" became the alias "123",
-- "0x1a2b" became "6699" and "12e456" became "inf". 16 * 32^5 is about 5e8
-- names: `title_id` only sees this machine's folder, and two machines creating
-- a note before Syncthing delivers the other's practically never draw the same.
local alphabet = "0123456789abcdefghjkmnpqrstvwxyz"
local letters = "abcdefghjkmnpqrs"
local function random_id()
  local bytes = assert(vim.uv.random(6))
  local id = {}
  for i = 1, 6 do
    local set = i == 1 and letters or alphabet
    local n = bytes:byte(i) % #set + 1
    id[i] = set:sub(n, n)
  end
  return table.concat(id)
end

-- Where a new note with a bare name goes: the root of the project the current
-- buffer belongs to, or where the plugin would put it (next to the buffer)
-- inside `study/` or `hosts/`. Anywhere else, the dashboard included, is
-- `inbox/`, the free area for a note with no project yet: the vault root is
-- closed.
local function note_folder()
  local name = vim.api.nvim_buf_get_name(0)
  local rel = name ~= "" and vim.fs.relpath(vault, name) or nil
  local project = rel and rel:match("^projects/[^/]+/")
  if project then
    return project
  end
  if rel and (rel:match("^study/") or rel:match("^hosts/")) then
    return ""
  end
  return "inbox/"
end

-- `require` is also what loads the plugin when the call comes from outside a
-- markdown buffer (the dashboard).
local function create_note(id)
  local ok, actions = pcall(require, "obsidian.actions")
  if not ok then
    return vim.notify("obsidian.nvim is not loaded", vim.log.levels.WARN)
  end
  actions.new(id, function(note)
    note:open({ sync = true })
  end)
end

-- No prompt: a random name in `note_folder()`, for `<leader>or` to rename once
-- the note has a subject.
local function new_note()
  create_note(note_folder() .. random_id())
end

-- The prompt: a bare title goes to `note_folder()`, a path ("study/foo") is
-- taken as is, and an empty title is a random name. It stays next to the direct
-- one because `<leader>or` renames in the same folder (the LSP handler builds
-- `dirname(old_path)/new_name.md`), so a folder is only chosen at creation.
local function new_note_prompt()
  local folder = note_folder()
  vim.ui.input({ prompt = "New note (title or path from the vault root; empty for a random name): " }, function(id)
    if not id then
      return
    end
    id = vim.trim(id)
    if id == "" then
      id = random_id()
    end
    if not id:find("/", 1, true) then
      id = folder .. id
    end
    create_note(id)
  end)
end

-- A link by name (`[[foo]]`) is found anywhere in the vault, so it survives the
-- note moving to another folder; a link with a path breaks. This prompts for
-- the note relative to the current note's folder (`../` climbs) and inserts
-- `[[<name>]]` at the cursor. A note that does not exist is created after a
-- confirmation, but never where the contract forbids (the header). Two notes
-- with the same name: the link goes to the first one found.
local function insert_link()
  local name = vim.api.nvim_buf_get_name(0)
  local rel = name ~= "" and vim.fs.relpath(vault, vim.fs.dirname(name)) or nil
  if not rel then
    return vim.notify("Not a note in the vault", vim.log.levels.WARN)
  end
  local base = rel == "." and "" or rel .. "/"

  vim.ui.input({ prompt = "Link from " .. (base == "" and "the vault root" or base) .. ": " }, function(input)
    input = input and vim.trim(input) or ""
    if input == "" then
      return
    end
    local target = vim.fs.normalize(base .. input):gsub("%.md$", "")
    if target == ".." or vim.startswith(target, "../") or vim.startswith(target, "/") then
      return vim.notify("That path leaves the vault", vim.log.levels.WARN)
    end
    local ok, obsidian = pcall(require, "obsidian")
    if not ok then
      return vim.notify("obsidian.nvim is not loaded", vim.log.levels.WARN)
    end
    local put = function(id)
      vim.api.nvim_put({ "[[" .. id .. "]]" }, "c", true, true)
    end

    -- The file is named by `note_id_func` ("Foo Bar" -> "foo-bar.md").
    local dir, title = vim.fs.dirname(target), vim.fs.basename(target)
    for _, id in ipairs({ title, require("obsidian.builtin").title_to_slug(title) }) do
      if vim.uv.fs_stat(vim.fs.joinpath(vault, dir, id .. ".md")) then
        return put(id)
      end
    end

    local closed = dir == "."
    for _, folder in ipairs({ "tasks", "decisoes", "daily" }) do
      closed = closed or vim.list_contains(vim.split(dir, "/"), folder)
    end
    if closed then
      return vim.notify(("'%s' does not exist, and no new note goes there"):format(target), vim.log.levels.WARN)
    end
    if obsidian.api.confirm(("Create new note '%s'?"):format(target)) ~= "Yes" then
      return
    end
    require("obsidian.actions").new(target, function(note)
      put(note.id)
    end)
  end)
end

return {
  {
    "obsidian-nvim/obsidian.nvim",
    version = "*",
    ft = "markdown",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    keys = {
      { "<leader>oo", "<cmd>Obsidian quick_switch<cr>", desc = "Quick switch note" },
      { "<leader>os", "<cmd>Obsidian search<cr>", desc = "Search notes" },
      { "<leader>on", new_note, desc = "New note" },
      { "<leader>oN", new_note_prompt, desc = "New note (title or path)" },
      { "<leader>oi", insert_link, desc = "Insert link from this note's folder" },
      { "<leader>oT", "<cmd>Obsidian template<cr>", desc = "Insert template" },
      { "<leader>ol", "<cmd>Obsidian links<cr>", desc = "Links in note" },
      { "<leader>ok", "<cmd>Obsidian backlinks<cr>", desc = "Backlinks" },
      { "<leader>ox", "<cmd>Obsidian toggle_checkbox<cr>", desc = "Toggle checkbox" },
      { "<leader>or", "<cmd>Obsidian rename<cr>", desc = "Rename note" },
      { "<leader>op", "<cmd>Obsidian paste_img<cr>", desc = "Paste image" },
    },
    opts = {
      legacy_commands = false,
      workspaces = {
        { name = "ObsidianVault", path = "~/ObsidianVault" },
      },
      -- `daily/` is generated; hides the daily commands from the menu (see the header).
      daily_notes = { enabled = false },
      -- The file is named after the title ("routines-and-headless.md"), not the
      -- default zettel id ("1791636016-BMOB.md"); a clash gets "-2", "-3"...
      note_id_func = function(title, dir)
        return require("obsidian.builtin").title_id(title, dir)
      end,
      -- render-markdown.nvim owns in-buffer rendering.
      ui = { enable = false },
    },
  },

  -- File finder over the vault: snacks.picker.files shells out to fd and
  -- matches the whole relative path, so a folder name narrows the list. It
  -- lives on snacks, not on obsidian.nvim, so it works from any buffer
  -- without loading the plugin.
  --
  -- The dashboard's `n` creates a note like `<leader>on` instead of an empty
  -- buffer (`<leader>fn` still does that). lazy.nvim replaces a list when it
  -- merges `opts`, so a `keys = {...}` table would wipe LazyVim's items and the
  -- `p` the snacks_picker extra inserts; the item is swapped in place, found by
  -- its key so the order the specs run in does not matter (freitask.lua puts
  -- its `K` after this one the same way).
  {
    "folke/snacks.nvim",
    keys = {
      {
        "<leader>oS",
        function()
          Snacks.picker.files({ cwd = vault, title = "Vault files" })
        end,
        desc = "Find vault files (fd)",
      },
    },
    opts = function(_, opts)
      local items = vim.tbl_get(opts, "dashboard", "preset", "keys") or {}
      for i, item in ipairs(items) do
        if item.key == "n" then
          items[i] = { icon = "󰠮 ", key = "n", desc = "New Note", action = new_note }
        end
      end
    end,
  },

  -- Name the <leader>o group in which-key. The function form mutates the
  -- existing spec instead of replacing LazyVim's default `opts.spec`.
  {
    "folke/which-key.nvim",
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      table.insert(opts.spec, { "<leader>o", group = "obsidian", icon = "󰠮" })
    end,
  },
}
