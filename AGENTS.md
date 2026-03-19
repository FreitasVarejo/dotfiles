# AGENTS.md - Dotfiles Repository Guide

This document provides guidelines for AI agents working in this dotfiles repository.

## Repository Overview

Personal dotfiles repository using **GNU Stow** for symlink management. Each
top-level directory (bash, git, nvim, tmux, conda) is a "stow package" that
mirrors the target structure from `$HOME`.

### Directory Structure

```
dotfiles/
├── bash/.bashrc                    # → ~/.bashrc
├── conda/.condarc                  # → ~/.condarc
├── git/.config/git/config          # → ~/.config/git/config
├── nvim/.config/nvim/              # → ~/.config/nvim/
│   ├── init.lua
│   └── lua/{config,plugins}/
├── tmux/.config/tmux/tmux.conf     # → ~/.config/tmux/tmux.conf
├── healthcheck.sh                  # Dependency checker
└── setup.sh                        # Installation script
```

## Commands

### Setup & Validation

```bash
./healthcheck.sh                    # Check dependencies before installation
./setup.sh                          # Apply configs (creates symlinks via stow)

# Linting (optional)
shellcheck healthcheck.sh setup.sh  # Lint shell scripts
nvim --headless "+q"                # Verify Neovim config loads
tmux source-file ~/.config/tmux/tmux.conf  # Check tmux syntax
```

**No formal test suite** - this is a config repository. Validation is done via
`healthcheck.sh` which checks for required dependencies.

## Code Style Guidelines

### Shell Scripts (Bash)

```bash
#!/bin/bash

# Color-coded logging (standard pattern used throughout)
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO] $1${NC}"; }
log_success() { echo -e "${GREEN}[OK] $1${NC}"; }
log_warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}"; }

# Command existence checks
if command -v tool_name &>/dev/null; then
    # tool exists
fi
```

- Use `[[ ]]` for conditionals, not `[ ]`
- Check command existence before use
- Use `exit 1` for fatal errors with helpful messages
- Comments: Portuguese or English both acceptable

### Neovim Lua (LazyVim)

**Indentation:** 2 spaces

**Plugin specs** (one file per plugin/group in `lua/plugins/`):
```lua
return {
  {
    "author/plugin-name",
    event = "VeryLazy",  -- lazy loading: event, cmd, keys, or ft
    opts = { },
    keys = {
      { "<leader>xx", "<cmd>Command<cr>", desc = "Description" },
    },
  },
}
```

**Options, keymaps, autocmds:**
```lua
vim.opt.setting = value
vim.opt_local.setting = value  -- buffer-local

vim.keymap.set("n", "<leader>key", function()
  -- action
end, { desc = "Description of keymap" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown" },
  callback = function()
    vim.opt_local.wrap = true
  end,
})
```

**File organization:**
- `lua/config/options.lua` - Vim options
- `lua/config/keymaps.lua` - Key mappings
- `lua/config/autocmds.lua` - Autocommands
- `lua/config/lazy.lua` - Plugin manager bootstrap
- `lua/plugins/*.lua` - Plugin specifications

### Tmux Configuration

```tmux
# --- SECTION NAME ---
bind key command
unbind key

# Plugins (TPM)
set -g @plugin 'author/plugin-name'
set -g @plugin_option 'value'
```

### Git Configuration

```ini
[alias]
  co = checkout
  st = status -sb
  # Shell commands use ! prefix
  lg = !git log --graph --all --pretty=format:'...'
```

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Stow packages | lowercase, singular | `bash`, `nvim`, `tmux` |
| Shell functions | snake_case | `log_info`, `backup_file` |
| Shell variables | UPPER_SNAKE_CASE | `BACKUP_DIR`, `ALL_GOOD` |
| Lua variables | snake_case | `lazypath`, `git_name` |
| Lua plugin files | kebab-case or single word | `tmux-navigator.lua`, `writing.lua` |

## Error Handling

**Shell:** Check command existence, use `exit 1` for fatal errors, provide hints.
**Lua:** Use `pcall()` or conditionals for optional features; degrade gracefully.

## Adding New Configurations

1. Create stow package directory: `mkdir new-tool`
2. Mirror the target path structure inside it
3. Add configuration files
4. Run `./setup.sh` to apply
5. Update `healthcheck.sh` if new dependencies required

## Dependencies

Required tools (checked by `healthcheck.sh`):
- **System:** git, stow, curl, make, gcc
- **CLI:** tmux, rg (ripgrep), fd, bat, fzf, zoxide, starship
- **Editor:** nvim (v0.9+)
- **Tmux:** TPM (Tmux Plugin Manager)
