# Formato de cards do repeater

Resumo da documentação oficial (shaankhosla.github.io/repeater, seções *Card Format* e *Parsing Logic*). Se a doc ou o repositório estiverem disponíveis no contexto, confira lá — ela prevalece sobre este arquivo.

## Tipos de card

```markdown
Q: Pergunta
A: Resposta, pode ter
várias linhas.

---

C: O grupo primário fica em [/etc/passwd] e os secundários em [/etc/group].

---
```

Existe também o card de linha única `pergunta::resposta`. **Não use** — e veja as armadilhas abaixo, porque qualquer linha com `::` vira card.

## Regra de contagem (a mais importante)

- `Q:`/`A:` → **1 card**.
- `C:` com N lacunas `[...]` não vazias → **N cards**. Cada lacuna é revisada separadamente, com as outras visíveis.
- Linha com `::` → 1 card.

O orçamento de 100 é de cards reais: conte lacunas, não blocos.

Consequência de estilo: `C:` com 1 a 3 lacunas. Com 4 ou mais, quase sempre é melhor um `Q:` cobrando a tabela inteira — ensina o mesmo e custa 1 card.

## Como o parser funciona

- Um card começa em `Q:`, `C:` ou numa linha com `::`, **na coluna 0**. Marcadores indentados são ignorados.
- O card termina num `---` na coluna 0 ou no início do próximo card.
- Sem `---`, tudo que vier depois (inclusive headings e anotações) passa a fazer parte da resposta do último card.
- `Q:` sem `A:` (ou com `A:` vazio) é erro de parse.
- Lacunas vazias `[]` são ignoradas.
- Cada card recebe um hash das letras, números e sinais `+`/`-`. Pontuação, espaços e maiúsculas não mudam o hash; mudar palavras cria um card novo e perde o histórico. Mover o card entre arquivos é seguro.

## Armadilhas (geram cards fantasmas ou quebrados)

| Armadilha | Efeito | Como evitar |
| :--- | :--- | :--- |
| Qualquer `[...]` dentro de um `C:` | vira lacuna: `[[04-03-...]]`, `[texto](url)`, `File[0-9]`, `[ -f arq ]`, `[a-z]` | em `C:`, colchetes só para lacunas; conteúdo com colchetes vai num `Q:` |
| Linha contendo `::` em qualquer lugar do arquivo (card ou anotação) | vira card de linha única | evitar em cards; IPv6 (`::1`), `std::`, `Class::method` → reescreva ou confira com `repeater check`. Nas anotações do usuário, só avise |
| Linha começando com `Q:`, `A:` ou `C:` nas anotações (ex.: `C:\Windows`, "Q: minha dúvida") | vira card ou quebra parse | nas anotações, apenas avise o usuário |
| Último card sem `---` | anotações/headings seguintes entram na resposta | todo card termina com `---`, inclusive o último do arquivo |
| `---` na coluna 0 dentro da resposta (ex.: em bloco de código) | corta o card no meio | não usar `---` dentro de cards |
| `Q:` ou `C:` na coluna 0 dentro de um bloco de código da resposta | abre card novo | evitar linhas de código começando assim |

## Conferência

- `python scripts/count_cards.py <arquivos ou pasta> --budget 100` imita estas regras, conta por arquivo e lista armadilhas.
- A verificação definitiva é do próprio repeater: `repeater check --plain <pasta>` (reindexa e mostra o total).
