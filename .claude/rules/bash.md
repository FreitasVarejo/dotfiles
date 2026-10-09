---
paths:
  - "bash/**"
  - "vault/.local/bin/**"
  - "**/*.sh"
---

# Shell scripts

- `[[ ]]` for conditionals, never `[ ]`. Loop arrays with `for x in "${arr[@]}"` — the
  `"{arr[@]}"` typo iterates over a literal string.
- Install hints use `$PM_INSTALL` (from `lib/common.sh`), never a hardcoded `apt`.
- Functions `snake_case`, variables `UPPER_SNAKE_CASE`.
- Files sourced via `bash --rcfile` must not define bare-symbol functions like `??()`:
  the bash 5.2 parser rejects them; wrap in `eval` if unavoidable.
- `~/.bashrc.d` is the stowed repo directory, so it can't hold secrets. Secrets and
  per-machine state go in `~/.bashrc.local`, which `bash/.bashrc` sources and git never sees.
- Never export `GITHUB_TOKEN`: `gh` keeps its own credential, and an exported secret
  reaches every child process, agents included.
