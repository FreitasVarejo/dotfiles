---
name: implementar
description: Implementa tasks do freitask que estão em Refinada ou Em implementação até Em homologação — uma, várias ou todas as disponíveis, em lote. Tria o que dá para fazer agora, executa uma task por vez num subagente pelo contrato do repo e propõe no fim o push, a PR e a label para o OK do dono. Use quando o dono pedir para implementar ou pegar uma task pelo id ou pelo nome, um lote delas, ou as que estão refinadas.
argument-hint: "[<id>...] (vazio: todas em Refinada e Em implementação)"
allowed-tools:
  - Bash(~/.claude/skills/implementar/scripts/lote)
  - Bash(~/.claude/skills/implementar/scripts/lote *)
  - Bash(freitask set *)
  - Bash(freitask list *)
  - Bash(freitask doctor *)
  - Read(~/ObsidianVault/**)
  - Edit(~/ObsidianVault/projects/**)
metadata:
  surfaces: "code"
---

# Implementar tasks

Você é a orquestradora: tria o lote, despacha um subagente por task, escreve no
vault e propõe o que sai da máquina. Quem escreve o código é o subagente. O
pedido do dono: $ARGUMENTS (vazio: todas as tasks em Refinada e Em
implementação).

Diga a fase pelo nome (Refinada, Em implementação, Em homologação). O callout
(`tip`, `example`, `question`) só aparece dentro do comando.

## 1. Fatos

Rode `~/.claude/skills/implementar/scripts/lote <ids>` (sem id, o lote
inteiro); o que cada linha quer dizer está no `--help` dele. Leia a nota da
máquina que ele aponta: ela diz em que repo esta máquina commita.

## 2. Triagem

Leia cada task do lote inteira e ponha cada uma em uma classe só, com o motivo
numa linha que cita o fato (o trecho da task ou a linha do `lote`):

| classe | quando |
|---|---|
| **já** | é código num repo vinculado, o desenho está fechado, e nada de que ela depende está por entregar |
| **espera** | depende de outra task, PR ou merge ainda não pronto: diga qual, e a fase dela |
| **do dono** | o que falta é passo dele ou não é código: decisão, estudo, ação no terminal ou numa conta dele |
| **em voo** | a branch do id tem worktree suja ou commit de menos de um dia que esta sessão não fez: outra sessão pode estar nela |
| **fora** | a fase não é de implementar (abaixo), o projeto não tem repo, ou a nota da máquina diz que daqui não se commita naquele repo |

A fase decide antes de tudo:

- **Não iniciada e Refinando** são fora: o desenho ainda não congelou
  (`~/ObsidianVault/AGENTS.md`, "Fase"). Sugira terminar o refino.
- **Bloqueada** é fora: mostre o motivo escrito na linha 4+ do bloco.
- **Em homologação** entra só quando o dono disse que a homologação reprovou, e
  então trabalha no que falhou.

A ordem das **já**: primeiro o que o texto das tasks impõe ("a primeira PR do
lote", "depois de"), depois a de prioridade alta. Depender do *merge* de outra
do mesmo lote é **espera**, porque o merge é do dono.

Mostre a tabela (task, classe, motivo) e a ordem das **já**, e espere o OK. O
dono pode mudar uma task de classe ou tirá-la do lote. A triagem termina quando
toda task do lote tem classe e motivo e o dono respondeu.

## 3. Uma task por vez

Para cada **já**, na ordem. A próxima só começa quando a anterior voltou: um
subagente por vez, em qualquer máquina.

1. **Abra.** Task em Refinada, ou em Em homologação reprovada:
   `freitask set <id> --status example --desc "DD/MM: em implementação pelo /implementar"`.
2. **Leia o contrato do repo**: `AGENTS.md` e `docs/agents/` da raiz do clone
   que o `lote` mostrou. Ele diz a branch, a worktree, a faixa, a forma dos
   commits e quantos agentes. O que ele dá à orquestradora (o commit do contrato
   antes das áreas, o merge das sub-branches, marcar item) é seu; o que ele dá a
   agente de área ou a revisor vai para um subagente. Contrato calado sobre isso:
   um subagente para a task inteira, no clone principal, na branch em que ele
   está.
3. **Despache** o subagente com o briefing de [briefing.md](briefing.md).
   Subagente novo, nunca fork: o contexto limpo é o motivo de ser um por task.
4. **Escreva o que voltou.** Só você escreve no vault: ele sincroniza com o
   celular, e dois escritores no mesmo arquivo dão `*.sync-conflict-*`.
   - Marque `- [x]` no item que tem commit na branch e `verificar` com PASSA.
   - `freitask set <id> --desc "DD/MM: …"`: o que foi feito e o que falta.
   - `## Para homologar`: o roteiro de testar à mão que voltou. O que abrir, o
     que fazer, o que deve acontecer, com o caminho infeliz.
   - `## Para retomar`, quando sobrou item, pergunta ou falha: os passos em
     ordem, cada um com o comando ou o arquivo. A próxima sessão não terá esta
     conversa.
5. **Fase.** Em homologação é quando o contrato do repo diz; se ele a liga a um
   passo para fora (PR, label), a task espera o plano, abaixo. Contrato
   calado: Em homologação (`freitask set <id> --status question`) quando todo
   item tem commit e PASSA, e o push fica para a `/fechar`. Parcial ou falhou
   sem PR a abrir: fica em Em implementação, e o lote segue para a próxima.

O achado fora do checklist vai para o relatório final, com o destino que o
contrato do repo dá. Contrato calado: task nova pela skill `freitask`, com OK
do dono. A task em voo fica como está (`~/ObsidianVault/AGENTS.md`, "Fase").

Esta etapa termina quando cada **já** acabou entregue, parcial ou falhou, e o
vault diz qual.

## 4. Plano

Depois da última task, um plano numerado (`P1`, `P2`…) com o que sai da
máquina, cada item com o comando pronto e o motivo, na ordem em que roda. Só
entram as tasks cujo contrato manda abrir PR, e o plano só tem:

- o push da branch `<id>`: `git -C <clone> push -u origin <id>`;
- a PR, pelo template do repo, citando a task e com o roteiro de homologação no
  corpo;
- a label ou o passo que o contrato pede para Em homologação.

O push na branch padrão é da `/fechar`, e o merge é do dono.

A resposta vale pela intenção: "ok" ou "todas" aprovam tudo, números aprovam
esses, "nenhum" não aprova nada. Rode um item por chamada do Bash, na ordem; o
item que depende de outro só roda se aquele rodou sem erro. Feito o passo que o
contrato pede, `freitask set <id> --status question --desc "DD/MM: …"`.

## 5. Fim

Rode `freitask doctor --quiet` sozinho, sem pipe. Sem saída é consistente; com
saída, mostre o achado ao dono e deixe o `--fix` para ele.

Relatório:

- **Lote**: task, classe, resultado (entregue, parcial, falhou, não começou) e
  a fase agora.
- **Plano**: o que rodou, o que falhou, o que ficou.
- **Espera você**: homologar (o roteiro está na task), as perguntas do "Para
  retomar" e os achados, cada um com o destino proposto.
- O push do repo sem esteira e a limpeza de worktree saem na `/fechar`.
