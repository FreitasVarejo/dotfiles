# Briefing do subagente

Preencha os `<…>` e mande como prompt de um subagente novo (`general-purpose`).
Ele não tem esta conversa: o que não estiver no briefing ele não sabe. Para
agente de área ou revisor que o contrato do repo pede, troque "Implemente a
task" pelo papel que o contrato dá e mantenha o resto.

O `general-purpose` vai com `model: sonnet`. Sem o `model`, ele herda o modelo
desta sessão, e a task chega refinada: escrever o código não pede Opus, e quem
revisa o que volta é você. A exceção é a task que é investigação antes de ser
código (um bug sem causa conhecida, uma falha que só aparece no CI): essa vai
sem `model`. Agente de área do contrato usa o modelo do próprio frontmatter.

```text
Implemente a task <id> no repo <clone>.

Leia antes de codar, inteiros:
- a task, <arquivo>, e as notas e ADRs que ela cita por wikilink
  (`find ~/ObsidianVault -name '<nome>.md'` resolve [[<nome>]]);
- o contrato do repo: AGENTS.md e docs/agents/ da raiz de <clone>;
- a nota desta máquina, <nota do host>.

Onde trabalhar: <a worktree e a branch que o contrato manda | o clone
principal, na branch em que ele está>.
Itens: <todos os `- [ ]` da task | os itens N e M>.
<Só na homologação reprovada: o que falhou, nas palavras do dono.>

Como trabalhar:
- O vault (~/ObsidianVault) é só leitura para você. Quem escreve na task é a
  sessão que te chamou, com o que você relatar.
- Commit na forma que o contrato pede; calado, um commit por item. Antes de
  cada commit, a skill `verificar`, e só commite com PASSA. Se a skill não
  abrir, rode `~/.claude/skills/verificar/scripts/portoes` na raiz do repo e
  leia o diff com as checagens de `~/.claude/skills/verificar/reference.md`.
- Seu trabalho termina no commit: push, PR, label e merge são da sessão que te
  chamou, com o OK do dono.
- Decisão que a task e o contrato não fecham: pare aquele item e devolva a
  pergunta, com o que o dono precisa saber para decidir. Os itens que não
  dependem dela seguem.

Relatório, nesta forma:
- Itens: cada um com feito ou não, o commit (hash curto) e a linha do
  verificar que prova.
- Git: a branch, a worktree, os commits à frente do origin e o que está sujo.
- Testar à mão: o roteiro que o verificar escreveu, ou "nada visível".
- Perguntas: cada decisão que travou um item.
- Achados: o que você notou fora dos itens, uma linha cada.
```
