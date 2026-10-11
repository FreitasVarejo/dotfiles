# Para onde vai cada resíduo

Regra em `~/ObsidianVault/projects/workflow-ia/decisoes/`, ADRs 0031 e 0039.

| Resíduo | Destino | Quem decide |
|---|---|---|
| trabalho que sobra de uma task | checklist e estado da task (`freitask set --desc`) | você |
| passo que depende do dono | "Para retomar" na task, em ordem | você |
| posse que a sessão tomou | apagar `dono`, `desde` e `dominio` | você |
| decisão de conversa ou adiamento | "Decidido" e "Adiado" do `estado-<host>.md`, pelo passo 5 da `current-project-state` | o dono |
| decisão que passa no critério de ADR da skill `domain-modeling` | proposta de ADR | o dono |
| regra para agentes | proposta de mudança no contrato | o dono |
| ponta solta sem task | task nova, pela skill `freitask` | o dono |
| task terminada | `freitask archive <id> done`, depois do portão | o dono |

## O que não se escreve

- **O que o script ou o coletor recalcula:** commit, lista de arquivos, título
  de PR, contagem. Isso envelhece e passa a mentir.
- **Task como wikilink no `estado-<host>.md`:** lá ela vai entre crases, pela
  regra da `current-project-state`. No corpo de task, o formato é o da skill
  `freitask`.
- **`## Histórico`:** é do freitask.
- **`daily/`:** não se escreve.
- **`*.sync-conflict-*`:** não se resolve; aponta-se.

## O que nunca se faz aqui

Commit, push, merge, `git worktree remove`, apagar branch, `mv` ou `rm` em
task. O que for limpeza vai para o relatório como comando, e quem roda é o
dono.

## Posse

`dono` é `<máquina>/<ferramenta>`: duas sessões na mesma máquina têm o mesmo
valor. Quem diz de qual sessão é a task é o script, pelo que as travas
anotaram. Só escreva em task desta sessão e só apague a posse dela; task e
posse de outra sessão vão para o relatório.

## "Para retomar"

Escreva os passos que a próxima sessão roda, em ordem, começando pelo que
destrava os outros, cada um com o comando ou o arquivo. Ela não vai ter esta
conversa: o que não estiver escrito ali não existe.
