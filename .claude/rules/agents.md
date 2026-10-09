---
paths:
  - "agents/**"
---

# The `agents/` package

Serves Claude Code (personal machines) and Cursor CLI (work WSL); Claude Code comes first
(ADRs 0024 and 0027 in `~/ObsidianVault/projects/workflow-ia/decisoes/`). Not stowed: every
target is a file the agents also write, so the setup hook links or merges instead
(`agents/hooks/lib.sh` says where each agent reads from). Merges only add or update what
the repo declares; whatever the machine added stays.

- `skills/<skill>/` → one symlink per skill in `~/.claude/skills/`. Never link `~/.claude`
  (it holds state) nor the whole skills dir (Claude Code writes `synced/` there).
- `mcp/<name>.json`: one file per server, the why in `mcp/README.md`. An MCP registered by
  hand and absent from this directory is a local experiment (ADR 0011).
- `permissions/deny.json`: what no agent may read or run, merged into each present
  agent's `permissions.deny`.
- `travas/`: one script per trava plus `travas.json` in Claude Code's `hooks` format
  (ADR 0028). A trava is for a rule whose breach is irreparable and cheap to detect;
  the rule's text stays where it lives (the vault's `AGENTS.md` is the floor for
  channels without hooks). A trava with no tool to call does nothing (ADR 0027).
- `settings/claude.json`: keys only Claude Code reads (`skillOverrides`, `autoMode`, …),
  merged key by key into its `settings.json` (ADR 0028). `autoMode` holds no project
  fact: the classifier reads it only from user scope, so it reaches every repo.
- `instructions/user.md` → `CLAUDE.md`, and `instructions/machines/<hostname>.md` →
  `rules/maquina.md`, both under `~/.claude/`, one symlink per file (ADR 0026). A line
  goes in `user.md` only when it holds in two repos and names no project noun.
- Skills policy (ADRs 0004, 0006, 0010): third-party skills are vendored copies with
  `metadata.upstream` / `upstream-commit` in the frontmatter — never `npx`, marketplace
  plugin or submodule. A skill is global only when it was really used in two repos and
  names no project noun. `metadata.surfaces` (`code`, `web`, `code,web`) says where a skill
  runs; `agents/hooks/build-web-zip.sh` zips the `web` ones for manual upload to claude.ai.
  Don't rewrite a vendored skill in the vendoring commit.
