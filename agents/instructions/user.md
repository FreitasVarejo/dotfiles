# Instruções de usuário

Valem em todo repo, em toda máquina com Claude Code.

## Vault

- `~/ObsidianVault` tem o mesmo caminho em toda máquina. Onde ele está em disco, leia e escreva os `.md` direto, sem MCP de Obsidian.
- Antes de criar, mover, renomear ou apagar qualquer coisa nele, leia `~/ObsidianVault/AGENTS.md`.
- Task não se move, renomeia, arquiva nem apaga com `mv`, `rm` ou edição à mão: use `freitask`. Ao terminar, `freitask doctor`.
- `daily/` não se reescreve. `*.sync-conflict-*` não se resolve sozinho.

## Como decidir comigo

- Decisão de desenho: explique o mecanismo por extenso (o que quebra, onde, com citação do código ou do contrato) antes de oferecer opções. Opção resumida em duas linhas esconde o que eu uso para escolher.
- Rodada de perguntas (ex.: `/grill-me`): texto numerado (Q1, Q2…), não `AskUserQuestion`. Respondo "1. B / 2. ok".
- Se eu questionar uma premissa sua, meça antes de responder.

## Escrever contrato (`AGENTS.md`, `CLAUDE.md`, `docs/agents/`)

- Só ponteiro e regra. Sem contagem, sem cópia de estado, sem afirmar o que uma ferramenta faz (aponte para `--help`).
- Sem futuro sobre ferramenta própria nem condicional de capacidade ("até X existir…"): ou existe e se escreve no presente, ou não se menciona.
- Caminho citado começa em `~/` e precisa existir; o `vault-lint` vigia.
- O porquê: ADRs 0009 e 0014 em `~/ObsidianVault/projects/workflow-ia/decisoes/`.
