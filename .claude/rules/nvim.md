---
paths:
  - "nvim/**"
---

# Neovim (LazyVim)

- 2-space indent. One plugin spec (or group) per file in `nvim/lua/plugins/`, named
  kebab-case or a single word; Lua variables `snake_case`.
- Options, keymaps and autocmds go in `nvim/lua/config/{options,keymaps,autocmds}.lua`.
- Optional features degrade gracefully (`pcall()` or a conditional), never an error at startup.
- A key a Lazy extra registers is deleted in `~/dotfiles/nvim/lua/config/keymaps.lua`, as
  `<leader>e` is; the why is in the comment there.
