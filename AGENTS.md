# AGENTS.md - Dotfiles Repository Guide

Personal dotfiles using **GNU Stow** for symlink management. Each top-level directory
(bash, git, nvim, tmux, yazi, vault, ssh) is a "stow package" that mirrors its target in
`STOW_TARGETS` (`setup.sh`). The exception is `agents`, a **hook-only package** (empty
target): nothing in it is stowed, so `setup.sh` only runs its setup hook.

## Architecture: thin orchestrators + per-package hooks

`setup.sh` and `healthcheck.sh` are **thin orchestrators**. The actual validation and
imperative setup logic lives _inside each package_ under `<pkg>/hooks/`:

```
lib/common.sh          # shared logging, package-manager detection (PM_INSTALL), check_cmd
setup.sh               # single source of truth: STOW_TARGETS map; stows then runs setup hooks
healthcheck.sh         # discovers and runs every <pkg>/hooks/check.sh, aggregates results
precommit.sh           # pre-commit gate over every shell/lua file git knows about
<pkg>/hooks/check.sh   # READ-ONLY dependency checks for that package; `exit $CHECK_FAILED`
<pkg>/hooks/setup.sh   # optional; state-mutating setup, runs AFTER that package is stowed
```

- Every hook sources `lib/common.sh` (via `DOTFILES_DIR/../..`) for logging + helpers.
- `check.sh` must stay read-only. Mark missing required deps with `fail_check` and end
  with `exit "$CHECK_FAILED"`. Anything that mutates state (writing git config, installing
  a plugin, registering MCP servers) belongs in `setup.sh`, not `check.sh`.
- `hooks/` directories are excluded from stow via each package's `.stow-local-ignore`.
- Rules that only matter inside one package or file type live in `.claude/rules/<x>.md`
  with `paths:`, and load when a matching file is touched. Never put an `AGENTS.md` or
  `CLAUDE.md` inside a stow package: it would be stowed into its target (`$HOME` for
  some). The why: ADR 0029 in `~/ObsidianVault/projects/workflow-ia/decisoes/`.

## Quick Reference

```bash
./healthcheck.sh                    # Check dependencies (runs all per-package check hooks); the required tools are whatever it checks
./setup.sh                          # Apply configs via stow + run setup hooks (backups if needed)
./precommit.sh                      # REQUIRED before any commit; must exit 0
./precommit.sh --list               # what it covers (derived from git, not from a glob)
```

**No formal tests** - config repo. `setup.sh` creates timestamped backup of conflicts
at `$HOME/dotfiles_backup_TIMESTAMP/`. Validate each change matches expectations.

## Freitask and the vault: wiring only

The freitask code lives in its own repo, `~/dev/freitask.nvim`, with its own contract.
Changes to task behaviour go there. This repo only carries the wiring:

- the CLI wrapper `vault/.local/bin/freitask` — with no arguments in a terminal it
  opens the TUI (`freitask-tui`);
- `vault/hooks/setup.sh` clones the repo and `cargo install`s the TUI; `vault/hooks/check.sh`
  checks both;
- in Neovim, `<leader>k` opens the TUI in a float (`nvim/lua/plugins/freitask.lua`) and saving
  a task runs `freitask rebuild` (`nvim/lua/config/autocmds.lua`).

`FREITASK_REPO` (default `~/dev/freitask.nvim`) is the single knob for where the clone
lives; the vault hooks and the CLI honour it. A per-machine override goes in
`~/.bashrc.local`, never in the repo.

The vault rules (tasks move only through `freitask`, `daily/`, sync conflicts) are the
vault's own contract: `~/ObsidianVault/AGENTS.md`.

`vault-checkpoint.timer` snapshots the vault into a git repo whose `GIT_DIR` lives outside
the synced folder (`~/.local/state/obsidian-vault.git`); inspect or undo with `vaultgit`.
Never commit it by hand.

`vault-lint` is the contract watchdog (`vault-lint --help`). It warns and never fails:
a dead pointer blocks nobody (ADR 0009).

## Adding New Configurations

1. Create stow package directory: `mkdir new-tool` (lowercase, singular)
2. Mirror the target path structure inside it
3. Add configuration files
4. Add the package to the `STOW_TARGETS` map in `setup.sh` (the one central list)
5. If it has dependencies, create `new-tool/hooks/check.sh` (read-only) — no edits to
   `healthcheck.sh` needed; it auto-discovers `*/hooks/check.sh`
6. If it needs imperative post-stow setup, create `new-tool/hooks/setup.sh`
7. Create `new-tool/.stow-local-ignore` containing `hooks` so the hook dir isn't symlinked
8. Run `./setup.sh` to apply

## Agent skills

### Issue tracker

Work lives as freitask tasks in `~/ObsidianVault/projects/workflow-ia/tasks/`, not GitHub issues (this repo has no pipeline). See `docs/agents/issue-tracker.md`.

### Domain docs

The _why_ lives in the vault, not here (ADR 0001): decisions in
`~/ObsidianVault/projects/workflow-ia/decisoes/`, glossary in
`~/ObsidianVault/projects/workflow-ia/glossario.md`. See `docs/agents/domain.md`.
