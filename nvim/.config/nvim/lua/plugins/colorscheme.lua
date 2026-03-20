-- Machine-specific theme detection
local function get_catppuccin_flavour()
  local hostname = vim.fn.hostname()

  -- Map hostnames to Catppuccin flavours
  local flavour_map = {
    ["fedora-41"] = "mocha",       -- gray/cool, neutral
    ["pi02"] = "macchiato",         -- soft/warm, easier on low-light
    ["BTGNOTE10113"] = "frappe",    -- cooler/blue, professional
  }

  -- Return matching flavour, or default to mocha
  return flavour_map[hostname] or "mocha"
end

return {
  -- Catppuccin colorscheme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = get_catppuccin_flavour(),
      transparent_background = false,
      integrations = {
        cmp = true,
        gitsigns = true,
        nvimtree = true,
        treesitter = true,
        notify = true,
        mini = {
          enabled = true,
        },
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { "undercurl" },
            hints = { "undercurl" },
            warnings = { "undercurl" },
            information = { "undercurl" },
          },
        },
      },
    },
  },

  -- Configure LazyVim to load catppuccin-nvim (new name after breaking change)
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-nvim",
    },
  },
}
