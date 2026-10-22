# Para onde vai cada resíduo

O porquê: ADRs 0031, 0039 e 0040 em
`~/ObsidianVault/projects/workflow-ia/decisoes/supersedidas/`.

| Resíduo | Destino | Quem decide |
|---|---|---|
| trabalho que sobra de uma task, código inclusive | checklist e estado da task (`freitask set --desc`); o item que toca caminho do CODEOWNERS do repo leva "pede revisão do dono na PR" | você |
| passo que depende do dono | "Para retomar" na task, em ordem | você |
| decisão tomada na sessão | destino da tabela da skill `domain-modeling` | o dono |
| adiamento | task nova (skill `freitask`) ou "Algum dia" (`freitask set <id> --status quote`) | o dono |
| pesquisa respondida | nota em `research/`, pela skill `research` | o dono |
| regra para agentes | proposta de mudança no contrato | o dono |
| ponta solta sem task | task nova, pela skill `freitask` | o dono |
| task terminada | `freitask archive <id> done`, depois do portão | o dono |

## O que não se escreve

- **O que o script ou o coletor recalcula:** commit, lista de arquivos, título
  de PR, contagem. Isso envelhece e passa a mentir.
- **`## Histórico`:** é do freitask.
- **`daily/`:** não se escreve.
- **`*.sync-conflict-*`:** não se resolve; aponta-se.

## O que nunca se faz aqui

Commit (é do dono, antes do `/fechar`), merge de PR ou merge que não seja
fast-forward, `--force`, `branch -D`, `git push --delete`, `mv` ou `rm` em
task. Push, fast-forward, limpeza e pull só pelo plano, abaixo.

## O plano

Os comandos vêm do `pendencias --plano`, nunca do modelo. A trava é o OK do
dono; a de reserva é a própria ferramenta: o git recusa árvore suja, branch não
mergeada e merge que não seja fast-forward, e o docker recusa rede em uso. O
que o git ignora (`.env`, cache, build) ele apaga junto com a worktree, sem
recusar, e por isso não tira a worktree do plano: o motivo do item nomeia cada
arquivo avulso que vai e resume as pastas. Não conte com o prompt de
permissão: em repo com `Bash(git *)` em allow, e em auto mode, ele não aparece.

**O push não tem essa reserva:** o git aceita qualquer fast-forward, inclusive o
commit de outra sessão. A reserva dele é só o OK, e o motivo do item lista os
commits que vão.

A lista é fechada (o que entra e o que fica "fora do plano": `pendencias --help`):

- `git -C <repo ou worktree da sessão> push <remote> <branch>`, sem `--force`
  nem `-u`;
- `git -C <clone principal> merge --ff-only <upstream>`, com o principal na
  branch padrão;
- `git -C <clone principal> worktree remove <caminho>`, sem `--force`, junto do
  `git -C <clone principal> branch -d <branch>` dela, nunca `-D`;
- `git -C <clone principal> branch -d <branch>` de branch fora de worktree;
  este e o de cima dependem do fast-forward quando o `branch -d` só aceita
  depois dele;
- `docker network rm <nomes>` das redes sem container, sem `prune` nem
  `--force`;
- num host que só consome os dotfiles (ADR 0034), `ssh <alias> 'git -C
  ~/dotfiles pull --ff-only'`, que depende do push quando é ele que deixa o
  host atrás, e, quando o script o propõe, o `./setup.sh` de lá, em background.

Clone de outro repo noutro host nunca vira item. A worktree desta sessão é
sempre a última; a de outra sessão entra como as outras, e o "de outra
sessão" do motivo só informa.

**Como o plano cresce:** tipo novo de comando entra no gerador do
`pendencias --plano` e nesta lista, na mesma mudança. O `allowed-tools` da
skill só ganha comando que não muda nada. Para o prompt de permissão voltar a
valer como reserva num comando que muda, a regra é uma `ask` em `permissions`,
como a do `Bash(cf-write *)` em `~/.claude/settings.json`.

## De qual sessão é a task

Quem diz é o script, pelo que as travas anotaram. Só escreva em task desta
sessão; a de outra sessão vai para o relatório.

## "Para retomar"

Escreva os passos que a próxima sessão roda, em ordem, começando pelo que
destrava os outros, cada um com o comando ou o arquivo. Ela não vai ter esta
conversa: o que não estiver escrito ali não existe.
