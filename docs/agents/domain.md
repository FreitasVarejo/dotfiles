# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

**Layout: single-context.** One `CONTEXT.md` and one `docs/adr/` at the repo root.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root: the glossary of domain terms.
- **`docs/adr/`**: read ADRs that touch the area you're about to work in.
- **`AGENTS.md`** at the repo root: the architecture and code-style contract for this repo.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront. The `/domain-modeling` skill (reached via `/grill-with-docs` and `/improve-codebase-architecture`) creates them lazily when terms or decisions actually get resolved.

## File structure

```
/
├── AGENTS.md
├── CONTEXT.md
├── docs/
│   ├── agents/                        ← this configuration
│   └── adr/
│       ├── 0001-thin-orchestrators-per-package-hooks.md
│       └── 0002-....md
├── lib/
└── <stow-package>/
```

This repo is single-context, so there is no root `CONTEXT-MAP.md` and no per-context `src/<context>/docs/adr/`. If the repo ever splits into genuinely separate contexts, add a `CONTEXT-MAP.md` at the root pointing at one `CONTEXT.md` per context and update this file.

Note that some domain lives *outside* this repo and `AGENTS.md` points at it: the freitask code and its docs are in `~/dev/freitask.nvim`, and the vault carries its own contract at `~/ObsidianVault/AGENTS.md`. Follow those pointers rather than re-deriving that domain from the wiring kept here.

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal: either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (event-sourced orders), but worth reopening because…_
