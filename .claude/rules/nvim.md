---
paths:
  - "nvim/**"
---

# Neovim (LazyVim)

- 2-space indent. One plugin spec (or group) per file in `nvim/lua/plugins/`, named
  kebab-case or a single word; Lua variables `snake_case`.
- Options, keymaps and autocmds go in `nvim/lua/config/{options,keymaps,autocmds}.lua`.
- Optional features degrade gracefully (`pcall()` or a conditional), never an error at startup.
- A Lazy extra that re-registers a default key can't be overridden in `keymaps.lua`: both
  load on `VeryLazy` in undefined order. Delete the key on `User LazyDone` instead, as
  `nvim/lua/config/autocmds.lua` does for `<leader>e`.
