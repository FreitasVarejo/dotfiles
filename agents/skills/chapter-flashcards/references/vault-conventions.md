# Convenções do vault

Extraídas do capítulo 04 (`04-managing-filesystems`), que é o modelo de referência. Se o vault divergir deste arquivo, siga o vault e avise.

## Estrutura

```
study/lpic-sybex-study-guide/
├── README.md                       ← índice do livro
├── prompts/CARD-BUDGET.md          ← regra de contagem + distribuições + duplicações
└── CC-titulo-do-capitulo/
    ├── README.md                   ← página do capítulo
    ├── REVIEW_QUESTIONS.md         ← mantido pelo usuário (respostas + correções)
    ├── CC-01-titulo-da-secao.md
    └── CC-02-titulo-da-secao.md
```

- `CC` e `SS` com dois dígitos. Slug: título em inglês do livro, minúsculo, palavras separadas por hífen, sem pontuação (`Using the systemd Initialization Process` → `05-05-using-the-systemd-initialization-process`).
- Pastas e arquivos existentes não são renomeados, mesmo que o slug não bata com o título (ex.: a pasta do capítulo 4 se chama `04-managing-filesystems`).
- Links internos por nome de arquivo sem extensão: `[[04-03-controlling-access-to-files]]`.

## Template: arquivo de seção novo

```markdown
---
id: CC-SS-titulo-da-secao
aliases: []
tags: []
---

# Chapter C.S: Section Title
```

O `id` é igual ao nome do arquivo sem `.md`. O H1 usa o número sem zero à esquerda (`Chapter 5.3`). As anotações do usuário ficam entre o H1 e os cards; a skill não escreve anotações.

## Template: seção de cards (sempre a última do arquivo)

```markdown
## Repeater Exercises

### Nome do subtópico

Q: Pergunta?
A: Resposta.

---

C: Frase com [lacuna].

---

### Outro subtópico

Q: ...
A: ...

---
```

- Uma linha em branco antes e depois de cada `---`.
- `### ` por subtópico, na ordem do livro, com nome curto em português.

## Estilo dos cards

Exemplos reais do vault (4.2):

```markdown
Q: `customers.txt` pertence a `Rich:sales` e precisa ficar com `Christine:marketing`. Que comando resolve em uma linha, e qual é a sintaxe geral?
A: `sudo chown Christine:marketing customers.txt`. A sintaxe geral é `chown owner:grupo ARQUIVO` — o ponto também é aceito (`owner.grupo`).

---

Q: Qual comando altera o usuário proprietário de um arquivo, quem pode executá-lo, e por quê?
A: `chown`, e somente o root. Um usuário comum não pode doar um arquivo seu porque isso permitiria burlar cotas de disco e se livrar da responsabilidade sobre o conteúdo.

---

C: A opção [-R] aplica `chown` e `chgrp` recursivamente a todos os arquivos e subdiretórios dentro de um diretório.

---

Q: Além de `newgrp` e `chgrp`, que outro mecanismo faz arquivos novos herdarem um grupo diferente do grupo primário do criador?
A: O bit SGID aplicado ao diretório — arquivos criados dentro dele recebem o grupo do diretório. (Ver [[04-03-controlling-access-to-files]].)

---
```

O que esses exemplos ensinam:

- Português, com comandos, opções, caminhos e valores em `crases`. Termos que a prova usa em inglês ficam em inglês (owner, display manager, runlevel).
- Perguntas de **cenário** ("X está assim e precisa ficar assado") são as mais valiosas: é o formato da prova.
- A resposta dá o fato e, quando ajuda a lembrar, o **porquê** ou o contraste — em 1 a 4 frases. Negrito só para separar itens de uma comparação.
- Um `Q:` pode cobrar várias coisas relacionadas de uma vez ("quais comandos exibem X, Y e Z") quando isso substitui vários clozes.
- `C:` só quando a lacuna é o próprio valor a memorizar, com 1 a 3 lacunas, sem outros colchetes.
- Links para outro capítulo/seção só dentro de `A:`.
- Nada de múltipla escolha, nada de "Verdadeiro ou falso".
- Livro com erro conhecido (ex.: gabarito errado)? O card ensina o correto e menciona a divergência em uma frase.

## Template: página do capítulo (`README.md`)

```markdown
---
id: CC-README
aliases: []
tags: []
---

# Chapter N: Chapter Title

## Objetivos do exame cobertos

- 101.2 Boot the system
- 102.2 Install a boot manager

## Seções

| # | Seção | Arquivo | Cards |
| :-: | :--- | :--- | --: |
| N.1 | Section Title | [[CC-01-titulo-da-secao]] | 8 |
| | **Total** | | **100** |

Perguntas de revisão do livro: [[REVIEW_QUESTIONS]]

## Exam Essentials — resumo

**Tópico em poucas palavras.** Resumo em português, com suas palavras, do que o livro diz para dominar nesse tópico — 1 a 3 frases, citando os comandos e arquivos principais.
```

- A linha de `REVIEW_QUESTIONS` só entra se o arquivo existir.
- Se o `README.md` já existir com Exam Essentials transcritas pelo usuário, não mexa nelas: atualize só a tabela de seções/cards.
- Os objetivos do exame (número + nome oficial da LPI) aparecem na abertura do capítulo no livro.

## Índice do livro (`README.md` da raiz)

Cada capítulo iniciado vira:

```markdown
### [[CC-titulo-do-capitulo/README|Chapter N: Chapter Title]]

| # | Seção |
| :-: | :--- |
| N.1 | [[CC-01-titulo-da-secao\|Section Title]] |
```

Note o `\|` escapado dentro da tabela. Remova o capítulo da tabela "Capítulos ainda não iniciados".
