---
name: fechar
description: Fecha uma sessão de trabalho sem perder o que sobrou — junta o que espera o dono (PR aberto, merge que destrava a etapa seguinte, limpeza depois do merge, outra máquina atrás), atualiza as tasks do freitask que a sessão tocou, pergunta o destino de cada ponta solta e propõe um plano de comandos (push do que está à frente, fast-forward do clone principal, limpeza de worktree, branch e rede vazia do docker, pull nas outras máquinas) que ela roda depois do OK do dono. Use quando o dono disser que vai fechar ou encerrar o chat.
disable-model-invocation: true
argument-hint: "[o que mais registrar antes de fechar]"
allowed-tools:
  - Bash(~/.claude/skills/fechar/scripts/pendencias *)
  - Bash(freitask set *)
  - Bash(freitask list *)
  - Bash(freitask doctor *)
  - Read(~/ObsidianVault/**)
  - Edit(~/ObsidianVault/projects/**)
metadata:
  surfaces: "code"
---

# Fechar a sessão

Você tem a conversa; o script tem o disco. Junte os dois para que a próxima
sessão comece sem precisar desta. Para onde vai cada coisa, e o que você nunca
faz: [reference.md](reference.md). Pedido extra do dono: $ARGUMENTS

1. **Fatos.** Rode
   `~/.claude/skills/fechar/scripts/pendencias --sessao ${CLAUDE_SESSION_ID} --plano`,
   com um `--repo <dir>` para cada repo que a conversa mexeu e o script não
   listou, e para cada worktree que a conversa (ou um subagente dela) criou ou
   usou, listada ou não: é o que põe o push dela no plano e a manda por
   último. Ele detalha o que é desta sessão e resume o de outras, e termina
   com o `## plano`. Fonte que diz "não consultei" não é "não há": diga qual.
2. **A cadeia.** Para cada coisa que espera o dono (PR aberto, ação manual,
   merge recente), escreva o que ela destrava e o que limpar depois. Ponha em
   ordem.
3. **Portão.** Para task que a sessão vai arquivar, ou que já arquivou, com
   `- [ ]` aberto, cada item pede uma decisão do dono: concluir, mover para
   task nova ou largar de propósito. Item ENTERRADO em `archived/` também.
4. **Pontas soltas.** O que a conversa notou e não resolveu, e que não está em
   task nenhuma nem no `## registro dos projetos` (decidido ou adiado): uma
   linha cada.
5. **Escrita.**
   - **Sem perguntar:** nas tasks desta sessão (as do script, mais as que a
     conversa mostra e ele não pegou), marque o que foi feito,
     troque o estado (`freitask set <id> --desc`) e deixe uma seção
     "Para retomar" com os passos em ordem.
   - **Só com OK:** arquivar, abrir task (skill `freitask`) e, quando a sessão
     produziu decisão, gravá-la pela skill `domain-modeling`. Adiamento é task
     ou "Algum dia" (`freitask set <id> --status quote`).
6. **Feche** com `freitask doctor --quiet`.
7. **Plano.** Depois do relatório, espere a resposta ao plano e rode só o
   que ela aprovou. As regras do plano estão em
   [reference.md](reference.md#o-plano).
   - Vale a intenção: "ok", "todas" ou "faça o plano" aprovam todos os
     itens; números aprovam esses; "nenhum", nada. Pergunte de novo só
     quando sobrar item em dúvida, e só por ele.
   - Antes de rodar, rode o `pendencias` de novo, com os mesmos argumentos, e
     compare o `## plano`: igual, rode; mudou, mostre o novo e pergunte.
   - Rode na ordem do plano, um item por chamada do Bash, cada comando como
     o script o imprimiu, sem acrescentar flag. O item que o script diz para
     rodar em background, rode em background. Se o git ou o docker recusar
     (árvore suja, branch não mergeada, push rejeitado, rede em uso), não
     contorne: o item fica no relatório, com a mensagem dele. Item que o
     classificador do auto mode negar também fica: vai para "Espera você",
     com o comando pronto atrás de `!`.
   - Item que depende de outro (o motivo diz qual) só roda se aquele rodou
     sem erro; senão, fica no relatório com o motivo.
   - Confira com `git -C <clone principal> worktree list` e diga o que rodou,
     o que falhou e o que ficou.

## Relatório

- **Feito no freitask**: o que você escreveu, task a task.
- **Plano**: os itens do `## plano` do script, como ele os imprimiu
  (`P1`, `P2`…), para resposta como `P: ok`, `P: 1, 3` ou `P: nenhum`.
  Sem item, diga que não há o que rodar.
- **Espera você**: em ordem, só merge de PR, revisão do dono, ação fora do
  alcance da sessão e item do plano negado (com o `!`), cada um com o que
  destrava. Código que sobra não entra aqui: vai para o checklist da task
  ([reference.md](reference.md)). Comando do plano também não: ou está no
  plano, ou ficou de fora dele por um motivo.
- **Decida**: portão e pontas soltas, numerados `D1`, `D2`…, para resposta no
  formato `D1 task, D2 larga`.
- **Fora de sincronia**: as linhas "fora do plano" do script, cada uma com o
  motivo, e o que ele não consultou.
