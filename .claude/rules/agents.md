---
paths:
  - "agents/**"
---

# The `agents/` package

Serves Claude Code (personal machines), Cursor CLI (work WSL) and OpenCode (work WSL, notebook); Claude Code
comes first (ADRs 0027 and 0046 in `~/ObsidianVault/projects/workflow-ia/decisoes/`, ADR 0024
in its `supersedidas/`). OpenCode is served only by files the setup generates or merges from
the same sources, and no file Claude Code or Cursor read changes for it. Not stowed: every
target is a file the agents also write, so the setup hook links or merges instead
(`agents/hooks/lib.sh` says where each agent reads from). Merges only add or update what
the repo declares; whatever the machine added stays.

- `skills/<skill>/` → one symlink per skill in `~/.claude/skills/`. Never link `~/.claude`
  (it holds state) nor the whole skills dir (Claude Code writes `synced/` there).
- `mcp/<name>.json`: one file per server, the why in `mcp/README.md`. An MCP registered by
  hand and absent from this directory is a local experiment (ADR 0011).
- `permissions/deny.json`: what no agent may read or run, merged into each present
  agent's `permissions.deny`; for OpenCode it is translated into `policies`, never into
  `permissions` (ADR 0046).
- `travas/`: one script per trava plus `travas.json` in Claude Code's `hooks` format
  (ADR 0028). A trava is for a rule whose breach is irreparable and cheap to detect;
  the rule's text stays where it lives (the vault's `AGENTS.md` is the floor for
  channels without hooks). A trava with no tool to call does nothing (ADR 0027).
- `settings/claude.json`: keys only Claude Code reads (`skillOverrides`, `autoMode`, …),
  merged key by key into its `settings.json` (ADR 0028). `autoMode` holds no project
  fact: the classifier reads it only from user scope, so it reaches every repo.
  `disableClaudeAiConnectors` stays on: an MCP reaches Claude Code only through `mcp/`,
  never through the claude.ai account, so nothing touches the vault around the travas.
- `statusline/claude-statusline`: the command `settings/claude.json` sets as `statusLine`.
  It reads the JSON Claude Code pipes on stdin; never let it exit non-zero or hang.
- `statusline/claude-subagent-statusline`: the command `settings/claude.json` sets as
  `subagentStatusLine`. It reads the JSON Claude Code pipes on stdin; never let it exit
  non-zero or hang. The color of each agent comes from the `color:` in its own
  `subagents/<nome>.md`, never from a map in the script.
- `mods/<mod>/`: a Claude Code mod, loaded from the repo by its path in the
  `CLAUDE_CODE_PLUGIN_DIRS` that `settings/claude.json` sets (`:`-separated, one per
  mod). A mod shows or asks; the rule it shows stays in its trava or skill, which the
  mod calls instead of copying. Its gate: `~/dotfiles/docs/agents/verificacao.md`.
- A third-party mod is a vendored copy of only what runs (`.claude-plugin/plugin.json`,
  `hooks/`, `LICENSE`) plus an `UPSTREAM` file naming the source URL and commit: never a
  marketplace install, never a path into a clone. Read its code before vendoring it, and
  don't rewrite it in the vendoring commit. Its tests stay upstream: the gate only
  validates a mod that has an `UPSTREAM`.
- `instructions/user.md` → `CLAUDE.md`, and `instructions/machines/<hostname>.md` →
  `rules/maquina.md`, both under `~/.claude/`, one symlink per file (ADR 0026). A line
  goes in `user.md` only when it holds in two repos and names no project noun. OpenCode
  gets the same two files through `instructions` in its `opencode.json`, by absolute path.
- `subagents/<nome>.md` → `~/.claude/agents/<nome>.md`, one symlink per file. Overriding
  a built-in by `name`: the Claude Code docs, sub-agents page.
- `opencode/`: only what OpenCode reads (ADR 0046). `config.json` is the fragment merged
  into its `opencode.json`; `commands/<nome>.md` are hand-written, one symlink per file.
  What the setup generates from `subagents/` and `skills/`: the docstring and the OpenCode
  section of `~/dotfiles/agents/hooks/agent_config.py`. A generated file carries the
  marker line; one without it is never touched. A tool name, `color` or `model` the
  translation does not know is a repo error: extend its map, never drop the entry.
  `modelos.json` is per machine and never enters the repo.
- Skills policy (ADRs 0004, 0006, 0010, 0017, 0041): third-party skills are vendored
  copies with `metadata.upstream` / `upstream-commit` in the frontmatter — never `npx`,
  marketplace plugin or submodule. A skill is global only when it was really used in two
  repos and names no project noun; one whose object is the vault or the machine's config
  from `~/dotfiles/setup.sh` is born global, and derives every project, repo, host and
  setting from disk or from the tool at query time. Any skill asks `vault-vinculos` which
  projects exist and which repos and hosts each one is linked to (the rule is in its
  `--help`). `metadata.surfaces` (`code`, `web`, `code,web`) says where a skill runs;
  `agents/hooks/build-web-zip.sh` zips the `web` ones for manual upload to claude.ai.
  Don't rewrite a vendored skill in the vendoring commit.
