# Trilha (`study/<repo>/trilha.md`)

Uma linha por capítulo que já teve tour, e só com o que ninguém consegue derivar: o tour
e o praticado. Mapeado, testado e desatualizado se derivam (a `SKILL.md` diz de onde) e
não se gravam.

## Modelo

````markdown
---
id: <repo>-trilha
aliases: []
tags: []
---

# Trilha

- **cap. 3, <nome do fluxo>** — tour 2026-11-09 · praticado 2026-11-20 (a1b2c3d)
- **cap. 4, <nome do fluxo>** — tour 2026-11-12
````

## Regras

- **A linha é `- **cap. N, <título do capítulo>** — tour <data>`**, e ganha
  ` · praticado <data> (<commit>)` quando o capítulo for praticado. O commit é o que
  provou o uso.
- **Linha nova** no fechar do tour; **"praticado"** muda a linha do capítulo no lugar. A
  trilha nova nasce com o frontmatter acima.
- **Capítulo sem tour não tem linha.**
