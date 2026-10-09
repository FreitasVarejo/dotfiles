---
name: fechar
description: Fecha uma sessão de trabalho sem perder o que sobrou — junta o que espera o dono (PR aberto, merge que destrava a etapa seguinte, limpeza depois do merge, outra máquina atrás), atualiza as tasks do freitask que a sessão tocou e pergunta o destino de cada ponta solta. Use quando o dono disser que vai fechar ou encerrar o chat.
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
   `~/.claude/skills/fechar/scripts/pendencias --sessao ${CLAUDE_SESSION_ID}`,
   com um `--repo <dir>` para cada repo que a conversa mexeu e o script não
   listou. Fonte que diz "não consultei" não é "não há": diga qual.
2. **A cadeia.** Para cada coisa que espera o dono (PR aberto, ação manual,
   merge recente), escreva o que ela destrava e o que limpar depois. Ponha em
   ordem.
3. **Portão.** Para task que a sessão vai arquivar, ou que já arquivou, com
   `- [ ]` aberto, cada item pede uma decisão do dono: concluir, mover para
   task nova ou largar de propósito. Item ENTERRADO em `archived/` também.
4. **Pontas soltas.** O que a conversa notou e não resolveu, e que não está em
   task nenhuma: uma linha cada.
5. **Escrita.**
   - **Sem perguntar:** nas tasks que a sessão tocou, marque o que foi feito,
     troque o estado (`freitask set <id> --desc`) e deixe uma seção
     "Para retomar" com os passos em ordem. Apague `dono`, `desde` e `dominio`
     que a sessão escreveu.
   - **Só com OK:** arquivar, abrir task (skill `freitask`) e gravar o
     `estado-<host>.md` (skill `current-project-state`).
6. **Feche** com `freitask doctor --quiet`.

## Relatório

- **Feito no freitask**: o que você escreveu, task a task.
- **Espera você**: em ordem, cada item com o que destrava. Os comandos de
  limpeza vão prontos para rodar com `!`.
- **Decida**: portão e pontas soltas, numerados, para resposta no formato
  "1. vira task / 2. larga".
- **Fora de sincronia**: o que o script achou nas outras máquinas, ou que não
  consultou.
