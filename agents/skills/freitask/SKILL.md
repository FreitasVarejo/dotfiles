---
name: freitask
description: Abre uma task do freitask no vault do Obsidian a partir do que o dono descrever, escolhendo o projeto pelo escopo de cada um (o MOC), com a pasta e o repo da sessão só como pista. Use quando o dono pedir para abrir, criar, anotar ou registrar uma task, uma frente de trabalho ou "uma coisa para fazer depois" — mesmo sem dizer "freitask". Hoje só abre task nova; mudar fase, arquivar, renomear ou mover de projeto continua sendo a CLI direto.
argument-hint: "<o que a task é, em uma ou duas frases>"
model: claude-sonnet-5-5
effort: xhigh
allowed-tools:
  - Bash(~/.claude/skills/freitask/scripts/contexto.sh)
  - Bash(~/.claude/skills/freitask/scripts/contexto.sh *)
  - Bash(freitask new *)
  - Bash(freitask kebab *)
  - Bash(freitask list *)
  - Bash(freitask set *)
  - Bash(freitask doctor *)
  - Read(~/ObsidianVault/**)
  - Edit(~/ObsidianVault/projects/**)
metadata:
  surfaces: "code,web"
---

# Abrir uma task do freitask

Você recebe o que o dono quer registrar (em `$ARGUMENTS`, ou na conversa) e sai
com uma task criada pela CLI, no projeto certo e com um corpo que diga o que ela
é. Os fatos sobre onde a sessão está vêm levantados abaixo. O julgamento é seu:
título, id, estado e corpo.

O pedido do dono: $ARGUMENTS

**No claude.ai**, os fatos e a escrita passam pelo conector do vault, porque lá
o `freitask` não roda: leia `references/claude-ai.md` agora e siga os §§ abaixo
com as trocas que ele dá.

## Contexto desta sessão

!`~/.claude/skills/freitask/scripts/contexto.sh`

## 1. Projeto

A regra é do vault (`~/ObsidianVault/AGENTS.md`, no parágrafo de criar task): o
projeto se escolhe pelo escopo. Nesta skill:

- **Escolha o projeto cujo escopo combina com o pedido**, lendo os escopos em
  "projetos do vault". As pistas (a pasta do vault, os backlogs que o repo
  alimenta) são ponto de partida, não decisão: uma sessão nos dotfiles alimenta
  mais de um projeto.
- **Dois escopos cabem, ou nenhum**: pergunte, na rodada única do §2,
  oferecendo os candidatos.
- **Pedido com duas entregas** de projetos diferentes vira duas tasks, uma em
  cada projeto, a segunda linkando a primeira. Nunca a mesma task duplicada.
- **Só use nome que está na lista.** O `freitask new` cria projeto novo em
  silêncio quando o nome não existe. Projeto novo só se o dono pedir com essas
  palavras.

Escolhido o projeto, liste as tasks ativas dele, sempre: é de onde vem a
checagem de duplicata do §2.

```bash
~/.claude/skills/freitask/scripts/contexto.sh tasks <projeto>
```

As de outro projeto, só quando dois escopos couberem ou quando o título pedido
parecer familiar. Não use `freitask list | grep`: o pipe tira o comando da
permissão da skill.

## 2. Perguntar ou criar direto

**Crie direto** quando o projeto está resolvido e a descrição diz o que é a
task. Cada pergunta custa: o modelo desta skill vale só no turno em que ela foi
chamada, e a resposta do dono já roda no modelo da sessão.

**Pergunte**, numa rodada só e com tudo junto, apenas quando:

- não há descrição nenhuma, nem em `$ARGUMENTS` nem na conversa;
- dois escopos de projeto cabem, ou nenhum (§1);
- a descrição cabe em duas tasks diferentes, e escolher uma seria chutar;
- uma task ativa do projeto parece ser a mesma coisa. Pergunte se é task
  nova ou um acréscimo àquela. Se for acréscimo, não crie nada: diga qual é a
  task e pare.

## 3. A task

- **Título**: uma frase curta em português, no tom das tasks da lista. Diga o
  que muda ("Rate limit no endpoint público de cadastro"), nunca algo genérico
  ("Melhorias de segurança").
- **id**: `freitask kebab "<2 a 5 palavras>"`. O id é o nome do arquivo **e** o
  da branch git, e é a única coisa cara de mudar depois: renomear reescreve
  referências no vault inteiro. Escolha curto e específico, e nunca um que já
  esteja na lista do projeto. Nem o de uma task de outro projeto: o `doctor`
  do §5 acusa id repetido entre projetos.
- **Estado** (`--desc`): uma linha começando pela data, no tom das existentes:
  "Aberta em DD/MM; <de onde veio, ou o que falta para começar>".
- **Fase**: a task nasce `todo`. Não mude.

```bash
freitask new <projeto> <id> "<título>" --desc "<estado>"
```

Os códigos de saída:

- **0**: imprime o caminho do arquivo.
- **1**: o motivo vem em stderr (id fora de kebab-case, ou já usado, inclusive
  por task arquivada). Ajuste e rode de novo.
- **2**: uso errado.

## 4. O corpo

Leia o arquivo criado e acrescente o corpo **depois do bloco**. O bloco são as
linhas iniciais que começam com `>`; não mexa nelas. Título e estado se trocam
com `freitask set <id> --title "…" --desc "…"`.

- **O que é e por quê**: um ou dois parágrafos, com as palavras do dono. Não
  invente requisito, prazo nem solução que ele não disse.
- **De onde veio**, quando a sessão está num repo: "Aberta em DD/MM numa sessão
  em `<repo>`, branch `<branch>`."
- **`## Pronto quando`**: só se o dono deu um critério verificável. Se não deu,
  deixe de fora; o critério nasce no refino.
- **Citações**: outra task vai como `[[projects/<p>/tasks/<id>|<id>]]` (o
  freitask reaponta o link quando ela muda de lugar). ADR vai como `[[NNNN-slug]]`.
- **Nunca escreva `## Histórico`**: é do freitask.

## 5. Fim

```bash
freitask doctor --quiet
```

Rode assim, sozinho: com `; echo $?` ou pipe, o comando sai da permissão da
skill. Sem saída nenhuma é 0, e está consistente. Se sair 1, rode `freitask doctor`
sem `--quiet` e mostre o achado ao dono. Não use `--fix` por conta própria.

Responda curto:

- projeto, e por que esse, em uma linha;
- `id` e caminho;
- o estado.

## Nunca

- Escrever o arquivo da task à mão onde o `freitask` roda: lá o caminho é o
  `freitask new`.
- `mv`, `rm`, renomear, arquivar ou `freitask delete`.
- `freitask current`, `freitask tui` ou `freitask` sem argumentos: abrem uma tela
  e travam a sessão.
- Editar o `CURRENT.md`: o `freitask new` já o regenera.

O resto das regras não se copia para cá, só se aponta:

- vault: `~/ObsidianVault/AGENTS.md`;
- freitask para agentes: `$FREITASK_REPO/docs/freitask.md` (ou
  `~/dev/freitask.nvim/docs/freitask.md`), seção "Para agentes de IA".
