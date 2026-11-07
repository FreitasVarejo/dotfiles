---
name: estudar-codebase
description: "Estuda uma codebase desconhecida: mapeia o domínio, os fluxos e as decisões num \"livro\" do vault (`study/<repo>/`), conduz o tour de um fluxo e diz o próximo passo pela missão, pela trilha e pelo placar. Use quando o dono quiser estudar, aprender ou fazer onboarding numa codebase, pedir para \"mapear o repo\", um \"tour do fluxo X\" ou \"o que estudo agora neste repo\". O teste do que foi aprendido fica com a `socratico`. Argumentos: `mapear`, `tour` ou `próximo`, e o fluxo, o ticket ou o capítulo."
argument-hint: "<mapear|tour|próximo> [fluxo, ticket ou capítulo]"
metadata:
  surfaces: "code"
---

# Estudar uma codebase

Modos para aprender uma base que o dono ainda não conhece: **mapear** escreve no
vault um "livro" dela, **tour** conduz o dono por um fluxo, **próximo** diz o que estudar
agora. O teste é da `socratico`, que lê esse livro como lê os de `study/` (a seção
"Quando a fonte é uma codebase" dela). Você grava em `mapa/`, na `trilha.md` e, uma vez,
no `README.md`; as notas do dono (`NN-<slug>.md`) e o `placar.md` são da `socratico`.

Pedido do dono: $ARGUMENTS

O modo costuma vir no pedido ("mapear o repo", "tour do fluxo X", "o que estudo agora");
sem pista, pergunte.

## A pasta do estudo

Vale para todos os modos.

1. A codebase é o toplevel do repo da sessão (`git rev-parse --show-toplevel`). Fora de um
   repo, pergunte qual.
2. A pasta é a de `~/ObsidianVault/study/*/README.md` cuja linha `- **Codebase:**` aponta
   para esse toplevel (`~` vale `$HOME`).
3. Nenhuma bate: `tour` e `próximo` dizem que não há mapa e propõem `mapear`; o primeiro
   `mapear` propõe `study/<basename do toplevel>/` no plano, e o dono pode trocar o nome.
4. Vault sem `study/`: leia o `AGENTS.md` dele, se houver, e pergunte antes de criar.

Pronto quando você sabe a pasta (ou que ainda não existe), o toplevel e o HEAD
(`git rev-parse --short HEAD`).

## O layout

```
study/<repo>/
├── README.md      adaptador: `- **Codebase:** <caminho>`, missão, Regras de estudo
├── mapa/          a fonte: 00-index.md (capítulos e "Como rodar e testar") e NN-<slug>.md
├── NN-<slug>.md   nota do dono, com os cards (socratico)
├── placar.md      da socratico, no formato dos livros
└── trilha.md      só tour e praticado
```

Antes de gravar um arquivo, leia o modelo dele: `references/adaptador-readme.md`,
`references/capitulo.md`, `references/00-index.md`, `references/trilha.md`.

Um **capítulo** é um fluxo de ponta a ponta, com o commit que foi lido no `sha:` do
frontmatter. Estados que se derivam e nunca se gravam: **mapeado** (o capítulo está em
`mapa/`), **testado** (o placar tem alguma linha `cap. N`) e **desatualizado** (o
`desatualizados.py` não dá `em dia`).

A **âncora** é `` `caminho/arquivo#Símbolo` (L120@abc1234) ``, e um método se escreve
`Classe.metodo`. O símbolo é o que vale; linha e sha só dizem onde olhar. O separador é
`#` porque o repeater lê qualquer linha com `::` como card, mesmo entre crases (medido
com `count_cards.py` e `repeater check --plain`).

## Mapear

O mapa é guiado pela **missão** (por que o dono precisa desta base agora), um capítulo
por vez.

1. **Missão.** Com README, leia-a. Sem README, pergunte ao dono e guarde a resposta para
   o texto do README (passo 4).
2. **Fluxo.** Com argumento (um fluxo, ou um ticket colado), vá direto a ele. Sem
   argumento, liste as **portas de entrada** da base (rotas, comandos, jobs,
   consumidores), ordene pela missão e proponha três, com uma linha de porquê cada.
   Pronto quando o dono escolheu um fluxo.
3. **Plano.** Diga o fluxo, a porta de entrada, o número e o nome do capítulo e, se for o
   primeiro, o nome da pasta. Espere o OK.
4. **Leia no HEAD**, da porta de entrada ao efeito final, e escreva o capítulo pelo
   `references/capitulo.md`, que também diz o estado de cada decisão. Arquivo sujo
   (`git status --short`) fica fora: o `sha:` só descreve commit.
5. **Grave.** O capítulo e o `mapa/00-index.md` direto. O README, na primeira vez, só
   depois de mostrar o texto inteiro e receber o OK.
6. **Confira**, e corrija até passar:

   ```bash
   python3 ~/.claude/skills/estudar-codebase/scripts/desatualizados.py <pasta-do-estudo>
   python3 ~/.claude/skills/socratico/scripts/count_cards.py <pasta-do-estudo>/mapa
   ```

   O capítulo novo sai `em dia`, e o `count_cards.py` dá 0 cards.
7. **Mostre** as decisões agrupadas por estado e as perguntas para o mantenedor num bloco
   que se copia de uma vez. Pronto quando o dono viu as decisões por estado e o bloco.

**Atualizar** é o mesmo caminho (plano, OK, grave, confira) para um capítulo que o
`desatualizados.py` não deu `em dia`, ou para a resposta do mantenedor. Releia no HEAD e
suba o `sha:` e o `mapeado`. Mantenha os títulos das seções, porque o placar cita por
eles, e aponte as linhas do placar cuja seção sumiu. Com a resposta do mantenedor, a
decisão sobe para `confirmada` e a pergunta sai.

`desatualizados.py --help` diz como ele decide `em dia`, `tocado` e `quebrada`.

## Tour

Um capítulo, um fluxo. O capítulo é o do argumento; sem ele, o primeiro sem tour. Rode o
`desatualizados.py` e diga ao dono o estado do capítulo.

Do começo ao fim, você pergunta, confirma e corrige contra o HEAD, citando
`arquivo#Símbolo`. Quem acha a resposta é o dono, e nenhum código muda. Nada se grava até
o fechar. O que não se acha no HEAD é **não verificável**: você não confirma nem corrige.

- **O primeiro tour do repo** (nenhuma linha `tour` na `trilha.md`) é **mostrado**. Você
  percorre os passos de `## O fluxo` pelas âncoras, um por mensagem. O dono abre o
  arquivo e explica o passo, e você confirma ou corrige.
- **Os seguintes** são **achados**. Você dá só a porta de entrada e o efeito final, e o
  dono acha o caminho narrando cada passo. As pistas vêm em degraus (arquivo, símbolo,
  linha), nunca o caminho inteiro.
- **Tentativas**, as da `socratico`: pista depois do primeiro "não sei", resposta só
  depois da segunda tentativa.
- **Depuração**, no fim: um sintoma plausível do fluxo, cuja origem você já localizou num
  símbolo do HEAD. O dono diz onde olharia, passo a passo, até achar esse símbolo.

**Tour feito** é chegar ao efeito final narrando cada passo e achar o símbolo da
depuração sem receber a resposta. No "fechar" do dono, com o tour feito, proponha a linha
da trilha (`references/trilha.md`) e grave com OK. Tour não feito: diga o que faltou e
não grave nada.

## Próximo

Só lê. Leia o `README.md` (a missão), a `trilha.md`, o `placar.md` e a saída do
`desatualizados.py`. Responda com **uma ação e a regra** da lista que a escolheu, a
primeira que valer:

1. Capítulo desatualizado que já teve tour ou teste: **atualizar** (`mapear`).
2. Capítulo em curso: sem tour, **tour**. Com tour e sem teste, **socrático**, com a
   frase pronta (`socrático de study/<repo> <N>`).
3. Revisão vencida: `erro` ou `hesitação` no placar há 7 dias ou mais, com a frase
   pronta. O `acerto` volta pela intercalação. O número é heurística, não medida.
4. Testado e não praticado: uma tarefa real, sem travar o resto. Quem escolhe a tarefa é
   o dono.
5. Nada disso: **mapear** o próximo capítulo pela missão.

Não se mapeia capítulo novo enquanto houver um sem tour.

**Praticado:** para o capítulo testado e sem `praticado` na trilha, rode
`git -C <codebase> log --author=<user.email do repo> <sha>..HEAD -- <arquivos das âncoras>`.
Com commit, proponha "praticado com o commit X" e grave na trilha com OK.
