# Índice do mapa (`mapa/00-index.md`)

Lista os capítulos e diz como rodar e testar a codebase. A `socratico` lê o índice para
achar os capítulos. Nasce junto com o primeiro capítulo, e cada capítulo novo entra nele.

## Modelo

````markdown
---
title: "<repo>"
source: codebase
---

# <repo>

## Capítulos

- [1. <nome do fluxo>](01-<slug>.md)
- [2. <nome do fluxo>](02-<slug>.md)

## Como rodar e testar

- `<comando>` — <o que faz>. Fonte: `caminho/arquivo`.
````

## Regras

- **Capítulos:** um por linha, na ordem do `NN`, com o nome do `title` do capítulo.
- **Como rodar e testar:** comandos que o repo declara (README, `Makefile`, scripts do
  `package.json`, workflow de CI), cada um com o arquivo de onde veio. Comando lido e
  não executado se diz assim. Subir a base, rodar os testes e rodar um teste só são o
  mínimo que o dono precisa para fazer a tarefa de depuração do tour.
