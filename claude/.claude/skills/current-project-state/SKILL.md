---
name: current-project-state
description: Diz em que pé está uma frente de trabalho, lendo o backlog do freitask, as notas do projeto no vault, o git dos repos, a esteira do GitHub e o host vinculado, e guardando um registro para a próxima rodada saber o que mudou. Use sempre que o dono perguntar o estado atual de um projeto, em que pé está, o que já está pronto, o que mudou desde a última vez, o que depende dele para revisar ou homologar, ou quais são os próximos passos — mesmo que ele não diga "skill" e chame o projeto por um apelido.
metadata:
  surfaces: "code"
---

# Estado atual de uma frente

Responde quatro perguntas sobre um projeto: **o que mudou**, **o que está
pronto**, **o que espera o dono** e **quais são os próximos passos**. Quem junta
os fatos é o coletor; você faz o julgamento que ele não sabe fazer, e no fim
grava o que a próxima rodada não conseguiria recalcular.

## 1. Rode o coletor

```bash
~/.claude/skills/current-project-state/scripts/coletar-estado.sh <projeto>
```

Leva uns 2 s com rede, 1 s sem. Ele imprime seções `##` já rotuladas.

| opção | quando usar |
|---|---|
| `--listar` | descobrir os projetos que existem, com os apelidos declarados |
| `--janela <dias>` | forçar a janela; o padrão é medir desde a última coleta gravada |
| `--gravar` | gravar o registro desta rodada (ver passo 5) |
| `--sem-rede` | pular GitHub e host — offline, ou quando pressa importa |
| `--host <alias>` | forçar o alias de SSH em vez do vinculado pela tag |
| `--json` | o documento canônico, para filtrar com `jq` |

`--help` mostra tudo. Sai 2 quando não sabe qual projeto é, e lista os que existem.

## 2. Resolva o nome antes

O dono chama os projetos pelo nome que usa, não pelo nome da pasta. O coletor
resolve apelido sozinho em cinco degraus (nome exato, `aliases:` do MOC, nome de
host vinculado, token em comum, prefixo comum) e diz no cabeçalho qual pedido
virou qual projeto.

Se ele sair 2 com a lista de projetos, **não chute**: olhe a lista, decida pelo
que a conversa diz e rode de novo com o nome da pasta. Se ainda estiver ambíguo,
pergunte ao dono — e, se o apelido vier a se repetir, o lugar de gravá-lo é o
`aliases:` do frontmatter do MOC do projeto no vault.

## 3. Leia o registro da rodada anterior

É a primeira seção depois das fontes. Ela traz o que a coleta não recalcula:

- **`coletado em`** — a janela desta rodada é medida a partir daí, e o cabeçalho
  diz há quanto tempo foi. Coleta recente com "mudanças" quase vazio significa
  **"nada mudou desde que você perguntou"**, não "o projeto está parado". Diga
  qual dos dois.
- **a fila com idade** — "PR #256 · 4 rodadas" é a informação que o GitHub não
  dá: há quatro vezes que você aparece aqui e isso continua esperando o dono.
  A data é quando o registro passou a ver o item, **não** quando ele nasceu; a
  idade real vem da linha `atualizado`, que o coletor traz viva.
- **decidido na conversa** e **adiado de propósito** — o que o dono já resolveu
  e o que ele mandou deixar quieto. **Não reapresente como novidade o que está
  em "adiado"**; mencione que segue adiado, e só.

## 4. Monte a resposta em quatro seções

Sempre estas quatro, nesta ordem. A tabela diz de onde sai cada uma:

| seção da resposta | de onde vem na saída do coletor |
|---|---|
| **Últimas mudanças** | `## mudanças na janela` — os três blocos: vault (ADR nova, spec reescrita, review), repos (commits, branch, árvore suja) e os planos de sessão |
| **O que está pronto** | tasks em `Pronta (check)` + `### Arquivadas na janela` (as `done`; `dropped` foi abandonada, não entregue) |
| **O que espera você** | `## esperando você` inteiro, cruzado com a idade que veio do registro |
| **Próximos passos** | tasks em `Não iniciada (todo)` e `Bloqueada (warning)` — a bloqueada primeiro, com o motivo, porque ela trava as outras |

Como narrar:

- **Cite id de task e data.** "`credenciais-dos-exporters`, parada desde 17/09" é
  verificável; "algumas pendências de infra" não é.
- **Ordene por impacto, não pela ordem da saída.** O coletor lista; você escolhe.
- **A linha `estado:` de cada task é o melhor resumo que existe** — é o itálico
  que o dono escreveu. Prefira-a a resumir o corpo da task por conta própria.
- **Cruze o host com as tasks.** Quando a frente tem host vinculado, o que está
  fora do ar confirma ou desmente o que a task afirma. Diga qual dos dois.
- **Leia `## fontes` antes de concluir.** Fonte `pulado`, `ausente`,
  `inacessivel` ou `vazio` significa que ninguém olhou ali: diga "não consultei",
  nunca "não há". As seções vazias por isso já vêm marcadas.
- **Um projeto pode ter pouco a dizer.** Frente sem MOC, sem ADR e sem repo local
  é um achado — reporte a lacuna em vez de encher linguiça.
- Os planos de sessão são **ponteiro, não fonte**: cite o caminho, e só abra se a
  resposta depender do que está lá.

## 5. Grave o registro

Ao fim da resposta:

```bash
~/.claude/skills/current-project-state/scripts/coletar-estado.sh <projeto> --gravar
```

Isso reescreve o frontmatter e a fila em
`~/ObsidianVault/projects/<projeto>/estado-<host>.md`, e **preserva intacta** a
prosa das três seções seguintes. Depois, edite só essas três:

- `## Decidido na conversa` — o que o dono resolveu e ainda não virou ADR. Uma
  linha datada por decisão. Decisão firme e estrutural **não** mora aqui: vira
  ADR em `decisoes/`.
- `## Adiado de propósito` — o que ele mandou deixar para depois, com o porquê.
  É o que impede a próxima rodada de cobrar de novo.
- `## Leitura da última rodada` — uma ou duas frases sobre onde a frente está.

Depois da primeira gravação, **só grave de novo quando a conversa produzir algo
irrecuperável** — uma decisão, um veto, um adiamento. Não grave a cada mensagem:
o vault tem checkpoint a cada 15 min e sincroniza com o celular.

**Nunca escreva no registro o que o coletor recalcula** — lista de task, de
commit, de ADR, de container, título de PR. Cópia de estado envelhece e passa a
mentir; o coletor refaz tudo isso em 2 s e nunca erra.

## 6. Duas regras invioláveis

**Task se cita entre crases, nunca como wikilink com caminho.** Arquivar uma
task muda o caminho dela — no vault, estar arquivada *é* o caminho — e o check 8
do `freitask doctor` marca link de task que não resolve como `error`
**irreparável**. Os dois vigias ignoram o que está entre crases, então crase é
imune por construção. ADR e nota de spec podem ir como `[[0057-...]]`: essas
quase não mudam de nome.

**Fora esse arquivo, não escreva em lugar nenhum.** Mudar fase de task,
arquivar, renomear ou criar é trabalho do `freitask`, e o `AGENTS.md` do vault
proíbe `mv`, `rm` e edição à mão em `tasks/`. Se o dono pedir uma dessas durante
a conversa, use a CLI.

## Armadilhas

- **`--sem-rede` esconde quase toda a seção "esperando você".** Hoje é no GitHub
  que moram os PRs abertos e as issues que pedem humano. Sem rede, você está
  respondendo sobre metade da pergunta; diga isso. Gravar offline **não** apaga
  a fila de PR e issue — o coletor preserva o que não conseguiu conferir.
- **Worktree não é frente nova.** O coletor deduplica pelo `git-common-dir` e
  mostra os worktrees de um clone como um repo com N branches em voo.
- **Task `dropped` que ficou com callout `todo`.** Ela aparece arquivada, não em
  "Não iniciada". Abandonada não é pendente.
- **Migração em massa entope o log do vault.** O bloco traz a contagem por gênero
  antes da lista e corta em 40; afunile com `--janela` menor em vez de narrar a
  enxurrada.
- **A contagem de commits tem teto de 30** e o coletor avisa quando bate nele.
- **Cada máquina tem o próprio registro.** `estado-fedora-workstation.md` e
  `estado-pi01.md` são arquivos diferentes de propósito: o vault sincroniza por
  Syncthing e não tem lock. Não console uma máquina com o registro da outra.

## Se algo falhar

- **Sai 2 com "não sei qual projeto é"**: nome não resolvido. Rode `--listar`.
- **`host: inacessível`**: o alias de SSH não respondeu. Verifique se o `Host` do
  host existe em `~/.ssh/config.local` (`ssh -G <alias>` mostra o usuário que
  seria usado) e se a VPN está de pé. O coletor tenta `<alias>` e `<alias>-local`.
- **`github: ausente` ou PRs vazios num repo que tem PR**: `gh auth status`.
- **`vault-lint: tem achado`** em `## avisos` é aviso por decisão, não erro.
  Não gaste a resposta com isso a menos que o dono pergunte.
