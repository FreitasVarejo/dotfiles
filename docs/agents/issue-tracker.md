# Issue tracker: freitask (vault do Obsidian)

Este repo **não tem esteira** (nenhum GitHub Action lê issue nenhuma), então o
trabalho não vive em GitHub Issues: vive como **task do freitask** em
`~/ObsidianVault/projects/workflow-ia/tasks/<id>.md`. Decisão em
`~/ObsidianVault/projects/workflow-ia/decisoes/0005-freitask-e-frente-issue-e-execucao-onde-ha-esteira.md`.
Regras do vault: `~/ObsidianVault/AGENTS.md` — leia antes de criar ou mexer em task.

## Convenções

- **Criar uma task**: até `freitask new` existir (task `freitask-new`), crie o
  arquivo `~/ObsidianVault/projects/workflow-ia/tasks/<id>.md` no formato do bloco:
  ```markdown
  > [!todo] Título
  > [[projects/workflow-ia/tasks/<id>|<id>]]
  > _estado opcional, em itálico_
  texto livre
  ```
  `<id>` é kebab-case, igual ao nome do arquivo e ao nome da branch git (sem
  `feat/`). Depois rode `freitask doctor`.
- **Ler uma task**: `cat ~/ObsidianVault/projects/workflow-ia/tasks/<id>.md`.
- **Listar**: `freitask list [--json] [--archived]`.
- **Comentar / registrar progresso**: edite o corpo da task (linhas 4+ são texto
  livre) e a descrição em itálico da linha 3. Nunca escreva em `## Histórico`.
- **Mudar o status**: troque o callout da linha 1 (`todo`, `done`…; vocabulário
  em `.freitask/status.json`).
- **Fechar**: `freitask archive <id> done|dropped|failed`. Nunca `mv`/`rm`.
- **Renomear**: `freitask rename <id> <novo-id>`.

## Pull requests como superfície de triagem

**Não.** Dono único, sem contribuição externa.

## Quando uma skill disser "publicar no issue tracker"

Crie uma task do freitask em `projects/workflow-ia/tasks/`, como acima.

## Quando uma skill disser "buscar o ticket"

Leia o arquivo da task.

## Labels de triagem e wayfinding

Não se aplicam: o freitask não tem labels nem sub-issues, e `/triage` e
`/wayfinder` não fazem parte do repertório de skills deste workflow. Decisão que
sair de uma task vira ADR no vault (`projects/workflow-ia/decisoes/`); a task só
linka.
