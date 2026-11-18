# Juntar tasks sem código

O passo que a captura (`freitask`, §2) e a triagem do lote (`implementar`, §2)
chamam. Só se junta task em Não iniciada, Refinando ou Refinada e sem branch:
juntar é mexer em texto. Com código (Em implementação em diante) o agente só
sugere, e quem junta é o dono. O passo roda depois do OK do dono à proposta,
nunca antes.

A é a task que fica, a mais adiantada na fase; o dono troca na proposta. A fase
da A não muda.

## A seção na A

No fim do corpo da A, antes do `## Histórico` quando ele existe (é do freitask;
não mexa).

- **Pedido novo** (captura, não há B): `## Veio de um pedido (DD/MM)`, com o
  pedido nas palavras do dono. Se a sessão está num repo, acrescente "Pedido em
  DD/MM numa sessão em `<repo>`, branch `<branch>`."
- **Task B** (triagem): `## Veio da <B> (fundida em DD/MM)`, com o corpo da B: o
  que vem depois do bloco `>`, sem o `## Histórico`, e os títulos descem um
  nível. Os `- [ ]` da B ficam na seção, para contarem na A.

Depois: `freitask set <A> --desc "DD/MM: <o que entrou>"`.

## A B sai (só com task B)

Grave a A antes. A B só se move pelo `freitask` (`~/ObsidianVault/AGENTS.md`):

```bash
freitask archive <B> dropped
freitask set <B> --desc "DD/MM: fundida em [[projects/<projeto>/tasks/<A>|<A>]]"
```

## Fim

`freitask doctor --quiet`, sozinho. Sem saída é 0.

No claude.ai só o pedido novo se faz, escrevendo na A pelo conector
(`claude-ai.md`).
