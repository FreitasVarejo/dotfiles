# README.md do estudo (o adaptador)

`study/<repo>/README.md` liga a pasta à codebase e é o contrato da `socratico` para ela
(o "Regras de estudo" que ela lê no 1.1). Nasce no primeiro `mapear`: mostre o texto
inteiro ao dono e grave só depois do OK. O dono pode trocar qualquer linha.

## Modelo

````markdown
---
id: <repo>-README
aliases: [<repo>]
tags: []
---

# <repo>

- **Codebase:** ~/dev/<repo>

## Missão

<por que o dono precisa desta base agora, em uma ou duas frases, nas palavras dele>

## Regras de estudo

Contrato da skill `socratico` para esta codebase. Só regra e ponteiro: o que já foi
mapeado, testado ou praticado se descobre olhando `mapa/`, `placar.md` e `trilha.md`.

- **Fonte:** `mapa/` desta pasta, um arquivo por capítulo (`NN-<slug>.md`); o
  `00-index.md` dela lista os capítulos. A correção vale contra o código no HEAD da
  codebase: o mapa é roteiro, e as âncoras `arquivo#Símbolo` dele são o que se cita.
- **Notas de capítulo:** `<NN>-<slug>.md` na raiz desta pasta, com os cards no fim, em
  `## Repeater Exercises`.
- **Cards:** em português. Os termos do domínio ficam como o código os usa.
- **Casos:** situações reais da base (um bug, um pedido de mudança).
````

## Regras

- `- **Codebase:**` é uma linha só, com o toplevel do repo: o `desatualizados.py` e a
  descoberta da pasta leem essa linha. Escreva `~/` quando o caminho estiver sob o
  `$HOME`, porque o mesmo vault pode ser lido de máquinas com home diferente.
- A missão fica no README e só muda quando o dono disser.
- Restrição de caso que o dono pedir (um domínio fora de cogitação, por exemplo) entra
  como mais uma linha de "Regras de estudo".
