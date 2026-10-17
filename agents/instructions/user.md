# Instruções de usuário

## Vault

- `~/ObsidianVault` é o mesmo vault no notebook e no pi01 (Syncthing).
- Onde o vault está em disco, leia e escreva os `.md` direto, sem MCP de Obsidian.
- Antes de criar, mover, renomear ou apagar qualquer coisa nele, leia `~/ObsidianVault/AGENTS.md`.
- Task não se move, renomeia, arquiva nem apaga com `mv`, `rm` ou edição à mão: use `freitask`. Ao terminar, `freitask doctor`.
- `daily/` não se reescreve. `*.sync-conflict-*` não se resolve sozinho.

## Cloudflare

- Ler: `cf`. Mudar qualquer coisa: só `cf-write`, e só depois de eu aprovar o comando. Não contorne (binário do npm direto, `curl` na API, `cf auth login`). Comando certo: `cf cli search`. O porquê: ADR 0038 em `~/ObsidianVault/projects/workflow-ia/decisoes/`.

## Como decidir comigo

- Decisão de desenho: explique o mecanismo por extenso (o que quebra, onde, com citação do código ou do contrato) antes de oferecer opções. Opção resumida em duas linhas esconde o que eu uso para escolher.
- Rodada de perguntas (ex.: `/grilling`): texto numerado (Q1, Q2…), não `AskUserQuestion`. Respondo "1. B / 2. ok".
- Se eu questionar uma premissa sua, meça antes de responder.

## Escrever contrato (`AGENTS.md`, `CLAUDE.md`, `.claude/rules/`, `docs/agents/`)

- Só ponteiro e regra. Sem contagem, sem cópia de estado, sem afirmar o que uma ferramenta faz ou fará (aponte para `--help`).
- Caminho citado começa em `~/` e precisa existir; o `vault-lint` vigia.
- Cada regra é enunciada uma vez, onde mora o dado, no escopo mais estreito que a carrega quando precisa; nos outros lugares, ponteiro.
- O porquê: ADRs 0009, 0014 e 0029 em `~/ObsidianVault/projects/workflow-ia/decisoes/`.
