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
-- you are in, which from a task lands it inside `tasks/`. `new_note` below
-- puts it at the project root instead. The daily-note keys are gone for the
-- same reason: `daily/` holds generated snapshots, and with no
-- `daily_notes.folder` the plugin would write today's note in the vault root.
-- `daily_notes.enabled = false` only hides `today`, `yesterday`, `tomorrow`
-- and `dailies` from the `:Obsidian` menu and completion; typing
-- `:Obsidian today` by hand still creates that file.
local vault = vim.fs.normalize("~/ObsidianVault")

-- A bare title goes to the root of the project the current buffer belongs to,
-- or stays where the plugin would put it inside `study/` or `hosts/`; typing a
-- path ("study/foo") is taken as is. Anywhere else has no home in the contract.
local function new_note()
  local name = vim.api.nvim_buf_get_name(0)
  local rel = name ~= "" and vim.fs.relpath(vault, name) or nil
  local project = rel and rel:match("^projects/[^/]+/")
  local free_area = rel and (rel:match("^study/") or rel:match("^hosts/"))

  vim.ui.input({ prompt = "New note (title or path from the vault root): " }, function(id)
    if not id then
      return
    end
    id = vim.trim(id)
    if not id:find("/", 1, true) then
      if project then
        id = project .. id
      elseif not free_area then
        return vim.notify(
          "No home for a new note here: open a note under projects/<project>/ or type a path",
          vim.log.levels.WARN
        )
      end
    end
    local ok, actions = pcall(require, "obsidian.actions")
    if not ok then
      return vim.notify("obsidian.nvim is not loaded", vim.log.levels.WARN)
    end
    actions.new(id, function(note)
      note:open({ sync = true })
    end)
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
