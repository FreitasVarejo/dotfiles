# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

**Layout: the *why* lives in the vault, not in this repo.** ADR 0001 split the genres: the
repo carries the operational contract (`AGENTS.md` + `docs/agents/`), and the vault carries
the reasoning and the map. So there is no `CONTEXT.md` and no `docs/adr/` at this repo root,
and there should not be one — a decision recorded here would be a second source of truth.

## Before exploring, read these

- **`AGENTS.md`** at the repo root: the architecture and code-style contract for this repo.
- **`~/ObsidianVault/projects/workflow-ia/glossario.md`**: the glossary of domain terms.
- **`~/ObsidianVault/projects/workflow-ia/decisoes/`**: read the ADRs that touch the area
  you're about to work in. They are numbered and dated; `status: vigente` means in force,
  `status: supersedida` means read the one that replaced it.
- **`~/ObsidianVault/projects/workflow-ia/mapa-do-workflow.md`**: what the workflow *is*,
  in the present tense — machines, where each genre lives, skill channels, MCP.

Two more domains live outside this repo, and `AGENTS.md` points at them: the freitask code
and its docs are in `~/dev/freitask.nvim`, and the vault carries its own contract at
`~/ObsidianVault/AGENTS.md`. Follow those pointers rather than re-deriving that domain from
the wiring kept here.

## File structure

```
/
├── AGENTS.md                         ← the operational contract
├── docs/
│   └── agents/                       ← this configuration
├── lib/
└── <stow-package>/
    └── hooks/{check,setup}.sh
```

Single-context: one contract, no `CONTEXT-MAP.md`, no per-context subtree. If the repo ever
splits into genuinely separate contexts, add the map and update this file.

## Use the glossary's vocabulary

When your output names a domain concept (in a task title, a refactor proposal, a hypothesis,
a test name), use the term as the glossary defines it. Don't drift to synonyms the glossary
explicitly avoids — it exists because those exact terms collided in a real conversation.

If the concept you need isn't in the glossary yet, that's a signal: either you're inventing
language the project doesn't use (reconsider) or there's a real gap (note it for
`/domain-modeling`, which writes into the vault).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently
overriding:

> _Contradicts ADR 0009 (contract holds pointers only), but worth reopening because…_

A decision that comes out of a task becomes an ADR in the vault; the task only links to it.
