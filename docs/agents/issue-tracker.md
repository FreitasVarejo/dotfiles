# Issue tracker: freitask (vault do Obsidian)

Este repo **não tem esteira** (nenhum GitHub Action lê issue nenhuma), então o
trabalho não vive em GitHub Issues: vive como **task do freitask** no vault.
Decisão em
`~/ObsidianVault/projects/workflow-ia/decisoes/0005-freitask-e-frente-issue-e-execucao-onde-ha-esteira.md`.
Regras do vault: `~/ObsidianVault/AGENTS.md` — leia antes de criar ou mexer em task.

## Backlogs que este repo alimenta

- `~/ObsidianVault/projects/workflow-ia/tasks/`
- `~/ObsidianVault/projects/ambiente-de-dev/tasks/`
- `~/ObsidianVault/projects/homelab/tasks/`

Task nova se abre pela skill `freitask` (`~/dotfiles/agents/skills/freitask/SKILL.md`).

## Convenções

- Criar: pela skill `freitask`. Listar, mudar de fase, fechar e renomear: pela CLI
  (`freitask help`).
- Ler uma task é ler o arquivo.
- Comentar ou registrar progresso: no corpo da task (linhas 4+) e na descrição em
  itálico da linha 3. Nunca em `## Histórico`.

## Pull requests como superfície de triagem

**Não.** Dono único, sem contribuição externa.

## Quando uma skill disser "publicar no issue tracker"

Crie a task pela skill `freitask`, num dos backlogs acima.

## Quando uma skill disser "buscar o ticket"

Leia o arquivo da task.

## Labels de triagem e wayfinding

Não se aplicam: o freitask não tem labels nem sub-issues, e `/triage` e
`/wayfinder` não fazem parte do repertório de skills deste workflow. Decisão que
sair de uma task vai para o destino da tabela da `domain-modeling`
(`~/dotfiles/agents/skills/domain-modeling/SKILL.md`); a task só linka.
