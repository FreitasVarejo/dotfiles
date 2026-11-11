---
description: Monta o relatório de lacunas do OpenCode contra o Claude Code e o grava num arquivo datado, sem conteúdo do trabalho. O argumento é o que o dono notou
---

Você vai gravar o relatório de lacunas deste OpenCode em arquivo. O arquivo volta para casa e vai alimentar a decisão sobre o que consertar nos dotfiles; ele não pode carregar nada do trabalho.

O que o dono notou (pode vir vazio): $ARGUMENTS

## Entrada

Use o resultado do comando `/conferir` rodado nesta sessão. Se ele não rodou aqui, pare e peça ao dono para rodar `/conferir` antes, nesta mesma sessão; só continue sem ele se o dono disser que não dá, e então marque "conferência não rodada" em "Não deu para testar". Não refaça a conferência por conta própria e não invente resultado.

## Onde gravar

Num arquivo novo em `lacunas-opencode/` dentro da home do dono, com a data e a hora no nome: `lacunas-AAAA-MM-DD-HHMM.md` (use `date +%Y-%m-%d-%H%M`). Resolva o caminho absoluto com `printf %s "$HOME"`, crie a pasta com `mkdir -p` e grave nesse caminho absoluto. Nunca grave dentro do repo dos dotfiles, dentro de `~/ObsidianVault` nem dentro de nenhum repo: o arquivo fica fora dos dois. Não sobrescreva um arquivo que já exista.

## Formato fixo

Use exatamente estas seções, nesta ordem, e nenhuma outra:

```
# Lacunas do OpenCode, AAAA-MM-DD HH:MM

## Versão e commit
- OpenCode: <saída de opencode --version>
- Dotfiles: <hash curto do commit> (<N> arquivos modificados no clone)

## Passou
- <item da conferência>: <evidência em uma linha>

## Falhou
- <item>: <mensagem literal>
(ou: Nada falhou.)

## Não deu para testar
- <item>: <por quê>
(ou: Nada ficou sem testar.)

## Medição
- hostname, memória total e usada em MB, XDG_RUNTIME_DIR definida (sim/não),
  vault com .freitask/ (sim/não), número de repos com docs/agents/verificacao.md.

## Lacunas contra o Claude Code
### <título curto da lacuna>
- O que foi feito: <...>
- O que se esperava (do jeito do Claude Code): <...>
- O que aconteceu: <...>
(ou, sem nenhuma: Nenhuma lacuna notada.)
```

"Sem lacuna" é um relatório válido: se nada falhou e o dono nada notou, grave as seções com "Nada falhou." e "Nenhuma lacuna notada." e pare, sem inventar lacuna para preencher. Cada coisa que o dono notou vira uma lacuna; cada falha da conferência que for diferença de comportamento contra o Claude Code (e não defeito de instalação) também.

## Sem conteúdo do trabalho

Antes de gravar, releia o texto inteiro e troque por um marcador o que for do trabalho: nome de repo ou de projeto (`<repo>`), caminho que revele pasta do trabalho (`<caminho>`; os caminhos de `~/.config/opencode` e do repo dos dotfiles podem ficar), qualquer URL (`<url>`), endereço interno e valor de proxy (`<host-interno>`), código e comando do trabalho (`<omitido>`), nome de pessoa e de empresa. A mensagem literal de erro fica literal, só com esses marcadores no lugar. Na dúvida, omita e diga na própria linha que omitiu. Nenhuma chave, token ou cabeçalho, nunca.

## Ao terminar

Diga o caminho absoluto do arquivo, quantos itens há em "Falhou" e quantas lacunas, e lembre ao dono que o arquivo é o que se leva para casa. Não o copie para o repo nem para o vault.
