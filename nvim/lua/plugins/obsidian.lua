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
      { "<leader>on", "<cmd>Obsidian new<cr>", desc = "New note" },
      { "<leader>ot", "<cmd>Obsidian today<cr>", desc = "Today's daily note" },
      { "<leader>oy", "<cmd>Obsidian yesterday<cr>", desc = "Yesterday's daily note" },
      { "<leader>od", "<cmd>Obsidian dailies<cr>", desc = "Daily notes" },
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
      -- render-markdown.nvim owns in-buffer rendering.
      ui = { enable = false },
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
