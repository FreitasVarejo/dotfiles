# Capítulo do mapa (`mapa/NN-<slug>.md`)

Um capítulo é **um fluxo de ponta a ponta**, da porta de entrada ao efeito final. `NN`
tem dois dígitos e sobe um por capítulo; `00-index.md` é o índice, não um capítulo.

## Modelo

````markdown
---
title: "<nome do fluxo>"
sha: <commit lido: git rev-parse --short HEAD>
mapeado: <AAAA-MM-DD>
---

# <nome do fluxo>

## O fluxo

1. `caminho/arquivo#Símbolo` (L120@abc1234): o que acontece neste passo.
2. `caminho/outro#Classe.metodo` (L48@abc1234): o passo seguinte, e o que o liga ao anterior.

## Termos

- **termo** — o que ele nomeia neste domínio, em uma linha, e onde mora: `caminho/arquivo#Símbolo`.

## Decisões

- <decisão de arquitetura em uma linha> — inferida — pergunta em § O que este mapa não sabe
- <decisão> — corroborada — <ADR, commit ou PR>
- <decisão> — confirmada — <pessoa>, <AAAA-MM-DD>

## Padrões

- <convenção que o fluxo segue e que a base repete>, com `caminho/arquivo#Símbolo`.

## O que este mapa não sabe

### Perguntas para o mantenedor

```text
1. <pergunta sobre uma decisão inferida, completa o bastante para ser colada sozinha>
```

### Não seguido

- <chamada para fora do repo, despacho dinâmico, configuração de runtime ou flag que o fluxo cruza>

### Não verificado

- <o que não pôde ser conferido no código, e por quê>
````

## Regras

- **O `sha` é do capítulo**, porque cada capítulo é lido num commit. Atualizar sobe o
  `sha` e o `mapeado`.
- **Âncora em todo passo de `O fluxo`**, no símbolo que faz o passo (método como
  `Classe.metodo`). Linha e sha entre parênteses são só dica de onde olhar.
- **As seções são fixas e têm esses títulos**, porque o placar da `socratico` cita
  por eles. Seção sem conteúdo fica com o título e uma linha dizendo que não há.
- **Decisão tem um estado, escrito depois do travessão:**
  - `inferida` — veio só do código. Ganha pergunta em "Perguntas para o mantenedor"
    quando a missão depende dela;
  - `corroborada — <ADR, commit ou PR>` — um artefato a sustenta. Procure, do mais
    barato ao mais caro: `git log -S` ou `git blame` até o commit que introduziu o
    padrão, a descrição do PR, as issues ligadas, a ADR do repo;
  - `confirmada — <pessoa>, <data>` — uma pessoa que participou da decisão disse que é
    assim. Só o dono traz essa confirmação.
- **Nada no capítulo se lê como card** (o repeater lê qualquer linha com `::` como card,
  e `Q:`, `A:` e `C:` na coluna 0 também): `count_cards.py` sobre `mapa/` dá 0.
