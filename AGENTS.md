# AGENTS.md - Dotfiles Repository Guide

Personal dotfiles using **GNU Stow** for symlink management. Each top-level directory
(bash, git, nvim, tmux, conda, opencode, yazi) is a "stow package" that mirrors
`$HOME` structure.

## Architecture: thin orchestrators + per-package hooks

`setup.sh` and `healthcheck.sh` are **thin orchestrators**. The actual validation and
imperative setup logic lives *inside each package* under `<pkg>/hooks/`:

```
lib/common.sh          # shared logging, package-manager detection (PM_INSTALL), check_cmd
setup.sh               # single source of truth: STOW_TARGETS map; stows then runs setup hooks
healthcheck.sh         # discovers and runs every <pkg>/hooks/check.sh, aggregates results
<pkg>/hooks/check.sh   # READ-ONLY dependency checks for that package; `exit $CHECK_FAILED`
<pkg>/hooks/setup.sh   # optional; state-mutating setup, runs AFTER that package is stowed
```

- Every hook sources `lib/common.sh` (via `DOTFILES_DIR/../..`) for logging + helpers.
- `check.sh` must stay read-only. Mark missing required deps with `fail_check` and end
  with `exit "$CHECK_FAILED"`. Anything that mutates state (writing git config, installing
  a plugin, registering MCP servers) belongs in `setup.sh`, not `check.sh`.
- `hooks/` directories are excluded from stow via each package's `.stow-local-ignore`.
- Install hints use `$PM_INSTALL` (auto-detected dnf/apt/pacman/brew), never hardcoded `apt`.
- The Claude Code MCP server map lives in `opencode/hooks/mcp-servers.sh` (sourced by both
  the opencode check and setup hooks) — co-located with the `opencode.json` it mirrors.

## Quick Reference

```bash
./healthcheck.sh                    # Check dependencies (runs all per-package check hooks)
./setup.sh                          # Apply configs via stow + run setup hooks (backups if needed)

# Pre-commit validation (REQUIRED before any commit)
shellcheck -x -P SCRIPTDIR setup.sh healthcheck.sh lib/common.sh */hooks/*.sh  # Must pass
nvim --headless "+checkhealth" +qa  # Must load without errors
tmux source-file ~/.config/tmux/tmux.conf  # Syntax check
luac -p nvim/lua/config/*.lua nvim/lua/plugins/**/*.lua  # Lua syntax
```

**No formal tests** - config repo. `setup.sh` creates timestamped backup of conflicts
at `$HOME/dotfiles_backup_TIMESTAMP/`. Validate each change matches expectations.

## Freitask / daily notes (Obsidian)

Task/daily-note tracking over `~/ObsidianVault/tasks/`, driven by
`nvim/lua/util/freitask.lua` + `nvim/lua/plugins/freitask.lua`. **Full guide:**
[`nvim/docs/freitask.md`](nvim/docs/freitask.md).

**The vault has its own contract**, colocated with the data, for agents pointed
at the vault rather than at this repo: [`~/ObsidianVault/AGENTS.md`](file:///home/freitaspinhe/ObsidianVault/AGENTS.md).

**Never `mv`, `rm` or hand-edit to move/rename/archive a task.** Use the CLI —
it is the only thing that keeps the four coupled invariants in sync at once:

```bash
freitask archive <id> done|dropped|failed   # or unarchive / rename / list
freitask doctor [--fix]                     # verify; --fix repairs what is derivable
```

Invariants an agent must not break:

- One file per task: `tasks/<project>/<id>.md`, or
  `tasks/<project>/archived/<type>/<id>.md` when archived (`done|dropped|failed`).
  **Being archived is the PATH**, not a frontmatter flag.
- The top of the file is a callout: `> [!<callout>] <title>` /
  `> [[tasks/<project>/<id>|<id>]]` / optional `> _state description_` (italic
  is what identifies it, not position — omit the line entirely if empty) /
  lines 4+ free text, preserved verbatim.
  **Status is EXCLUSIVELY the callout type** (mapped via `tasks/status.json`,
  which covers all 27 render-markdown.nvim callouts, ordered `todo` → done →
  reference — see `tasks/STATUS.md`). Never write a status number anywhere.
- `<id>` = filename = git branch name (no `feat/`); line 2's wikilink target is
  the vault-relative path with `<id>` as alias — there is no separate `Branch:`
  line, and the frontmatter `id:` must match the filename.
- Renaming an id **breaks external backlinks irrecoverably** unless done through
  `freitask rename` / `M.apply_edit`, which call `M.retarget_links`. Archiving
  by hand is only *repairable* damage (`freitask doctor --fix`) — still use the CLI.
- Archiving/unarchiving append a dated line to the `## Histórico` footer. Do not
  write there by hand: the path stays the source of truth, and a history line
  without the corresponding move is just text lying about where the file is.
- `CURRENT.md` is generated (auto-regenerated on task save; previous day archived
  to `tasks/daily/`); only its `## Notas Avulsas` is hand-editable. `daily/` and
  `templates/` are reserved, not projects — and `daily/` must never be rewritten.
- `*.sync-conflict-*.md` (Syncthing, the vault syncs with a phone) are ignored by
  the tool on purpose and reported by `doctor`. Never resolve one unattended.
- Reuse `require("util.freitask").parse_block` / `serialize_block` (round-trip safe,
  handles YAML frontmatter + legacy formats) instead of ad-hoc regex.
  `serialize_block` needs `model.project` (and `model.archived`) to emit the link.
- `M.split_task_path(path)` → `project, id, archived` is the single guard for
  "is this a task file?". Extend it rather than adding a new `match` at a use site.

Safety net: `vault-checkpoint.timer` snapshots the vault every 15 min into a git
repo whose `GIT_DIR` lives **outside** the synced folder
(`~/.local/state/obsidian-vault.git`), so git and Syncthing never share a byte.
Inspect/undo with `vaultgit log|restore`. Never commit it by hand.

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
- **CRITICAL:** Loop over arrays with `for var in "${array[@]}"`, never `for i in "{array[@]}"`
- **NOTE:** Avoid bare-function syntax like `??()` / `!?()` in files sourced via
  `bash --rcfile` — bash 5.2 parser quirk in 2026.0+ requires `eval` if needed.

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

-- Lazy extras that re-register default keys (e.g. editor.snacks_picker binds
-- <leader>e / <leader>E) can't be overridden in keymaps.lua because both load
-- on VeryLazy in undefined order. Hook LazyDone and delete them after the fact.
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyDone",
  callback = function()
    pcall(vim.keymap.del, "n", "<leader>e")
    pcall(vim.keymap.del, "n", "<leader>E")
  end,
})
```

**File organization:**

- `lua/config/options.lua` - Vim options
- `lua/config/keymaps.lua` - Key mappings
- `lua/config/autocmds.lua` - Autocommands
- `lua/config/lazy.lua` - Plugin manager bootstrap
- `lua/plugins/*.lua` - Plugin specifications

**Notable non-default options** (`lua/config/options.lua`):

- `timeoutlen = 300` — wait time (ms) for a mapped key sequence to complete; lower
  than the default 1000 for snappier `<leader>`-prefixed keymaps.
- `ttimeoutlen = 100` — wait time (ms) for terminal/keyboard codes (e.g. ESC in
  insert mode); low value makes `<Esc>` feel instantaneous when it isn't part of
  a mapping, while still leaving 100 ms for arrow-key / function-key sequences.
- `swapfile = false` — disables `.swp` files; rely on git + undo (`vim.opt.undofile`)
  for recovery.

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

| Type             | Convention                | Example                             |
| ---------------- | ------------------------- | ----------------------------------- |
| Stow packages    | lowercase, singular       | `bash`, `nvim`, `tmux`              |
| Shell functions  | snake_case                | `log_info`, `backup_file`           |
| Shell variables  | UPPER_SNAKE_CASE          | `BACKUP_DIR`, `ALL_GOOD`            |
| Lua variables    | snake_case                | `lazypath`, `git_name`              |
| Lua plugin files | kebab-case or single word | `tmux-navigator.lua`, `writing.lua` |

## Error Handling

**Shell:** Check command existence, use `exit 1` for fatal errors, provide hints.
**Lua:** Use `pcall()` or conditionals for optional features; degrade gracefully.

## Adding New Configurations

1. Create stow package directory: `mkdir new-tool`
2. Mirror the target path structure inside it
3. Add configuration files
4. Add the package to the `STOW_TARGETS` map in `setup.sh` (the one central list)
5. If it has dependencies, create `new-tool/hooks/check.sh` (read-only) — no edits to
   `healthcheck.sh` needed; it auto-discovers `*/hooks/check.sh`
6. If it needs imperative post-stow setup, create `new-tool/hooks/setup.sh`
7. Create `new-tool/.stow-local-ignore` containing `hooks` so the hook dir isn't symlinked
8. Run `./setup.sh` to apply

## Dependencies

Required tools (checked by `healthcheck.sh`):

- **System:** git, stow, curl, make, gcc
- **CLI:** tmux, rg (ripgrep), fd (>= 8.4 for Snacks picker), bat, fzf, zoxide, starship
- **Editor:** nvim (v0.9+)
- **Tmux:** TPM (Tmux Plugin Manager)
- **Yazi:** catppuccin-mocha flavor (`cd ~/dotfiles/yazi && ya pkg install`)
- **C#:** Roslyn LSP via Mason (custom registry `github:Crashdummyy/mason-registry`),
  requires `.NET SDK` on PATH (`~/.dotnet`); `csharp-ls` is an alternative but not required.
- **Claude Code:** optional; if `claude` is on PATH, `opencode/hooks/setup.sh` registers
  the MCP servers listed in `CLAUDE_MCP_SERVERS` (in `opencode/hooks/mcp-servers.sh`) at
  user scope via `claude mcp add-json`, mirroring the enabled servers in `opencode/opencode.json`:
  `git`, `docker`, `github`, `obsidian`. `sqlite` is intentionally left out of Claude
  Code's registration — its opencode config uses a per-workspace path
  (`${workspaceFolder}/data/metadata.db`), which doesn't make sense as a single
  global `user`-scope entry.
  Not a stow package — Claude Code's user-scope MCP config lives inside the
  stateful `~/.claude.json`, so it's registered imperatively instead of symlinked.
- **`uv`/`uvx`:** required for the `obsidian` MCP server (`uvx mcp-obsidian`).
  `sudo dnf install uv` on Fedora; checked by `healthcheck.sh`.
- **Secrets (`GITHUB_TOKEN`, `OBSIDIAN_API_KEY`):** `~/.bashrc.d` is itself the
  stowed repo directory (`~/.bashrc.d` -> `dotfiles/bash/.bashrc.d`), so it can't
  hold untracked secrets. `bash/.bashrc` instead sources `~/.bashrc.local` if it
  exists — that file lives outside the repo and is never committed. Put
  `export GITHUB_TOKEN=...` (fine-grained PAT, used by the `github` MCP server) and
  `export OBSIDIAN_API_KEY=...` (from the Obsidian Local REST API plugin, used by
  the `obsidian` MCP server) in there.
- **Obsidian `obsidian-local-rest-api` plugin:** required by the `obsidian` MCP
  server. `setup.sh` (`install_obsidian_rest_api_plugin`) downloads the plugin into
  `~/ObsidianVault/.obsidian/plugins/` and registers it in `community-plugins.json`
  if the vault exists, but activation and API-key generation require opening
  Obsidian once (Settings > Community plugins > enable "Local REST API", copy the
  generated key into `OBSIDIAN_API_KEY`).
