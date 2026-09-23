---
name: current-project-state
description: Diz em que pé está uma frente de trabalho, lendo o backlog do freitask, as notas do projeto no vault, o git dos repos, a esteira do GitHub e o host vinculado. Use sempre que o dono perguntar o estado atual de um projeto, em que pé está, o que já está pronto, o que mudou desde a última vez, o que depende dele para revisar ou homologar, ou quais são os próximos passos — mesmo que ele não diga "skill" e chame o projeto por um apelido.
metadata:
  surfaces: "code"
---

# Estado atual de uma frente

Responde quatro perguntas sobre um projeto: **o que mudou**, **o que está
pronto**, **o que espera o dono** e **quais são os próximos passos**. Quem junta
os fatos é o coletor; você faz o julgamento que ele não sabe fazer.

Não invente nada e não escreva em lugar nenhum — esta skill é de leitura.

## 1. Rode o coletor

```bash
~/.claude/skills/current-project-state/scripts/coletar-estado.sh <projeto>
```

Leva uns 2 s com rede, 1 s sem. Ele imprime seções `##` já rotuladas.

| opção | quando usar |
|---|---|
| `--listar` | descobrir os projetos que existem, com os apelidos declarados |
| `--janela <dias>` | mudar a janela de "o que mudou" (padrão: 14 dias) |
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

## 3. Monte a resposta em quatro seções

Sempre estas quatro, nesta ordem. A tabela diz de onde sai cada uma:

| seção da resposta | de onde vem na saída do coletor |
|---|---|
| **Últimas mudanças** | `## mudanças na janela` — os três blocos: vault (ADR nova, spec reescrita, review), repos (commits, branch, árvore suja) e os planos de sessão |
| **O que está pronto** | tasks em `Pronta (check)` + `### Arquivadas na janela` (as `done`; `dropped` foi abandonada, não entregue) |
| **O que espera você** | `## esperando você` inteiro — PRs abertos, issues com label pedindo humano, tasks em `Em homologação (question)`, notas avulsas do painel, notas de spec com pendências |
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
- **Um projeto pode ter pouco a dizer.** `homelab` não tem MOC nem ADR e não tem
  repo local. Isso é um achado — reporte a lacuna em vez de encher linguiça.
- Os planos de sessão são **ponteiro, não fonte**: cite o caminho, e só abra se a
  resposta depender do que está lá.

## 4. Nunca escreva

Mudar fase de task, arquivar, renomear ou criar é trabalho do `freitask`, e o
`AGENTS.md` do vault proíbe `mv`, `rm` e edição à mão em `tasks/`. Se o dono
pedir uma dessas durante a conversa, use a CLI — esta skill não faz, e o coletor
também não.

## Armadilhas

- **`--sem-rede` esconde quase toda a seção "esperando você".** Hoje é no GitHub
  que moram os PRs abertos e as issues que pedem humano. Sem rede, você está
  respondendo sobre metade da pergunta; diga isso.
- **Worktree não é frente nova.** O coletor deduplica pelo `git-common-dir` e
  mostra os sete worktrees de um clone como um repo com sete branches em voo.
  Não os narre como sete projetos.
- **Task `dropped` que ficou com callout `todo`.** Ela aparece arquivada, não em
  "Não iniciada". Abandonada não é pendente.
- **Migração em massa entope o log do vault.** Um commit que moveu todas as tasks
  de lugar mostra dezenas de arquivos num dia só. O bloco `## mudanças na janela`
  traz a contagem por gênero antes da lista, e corta em 40; afunile com
  `--janela` menor em vez de narrar a enxurrada.
- **A contagem de commits tem teto de 30** e o coletor avisa quando bate nele.
  Bateu, é sinal de semana cheia — conte isso em vez de listar tudo.

## Se algo falhar

- **Sai 2 com "não sei qual projeto é"**: nome não resolvido. Rode `--listar`.
- **`host: inacessível`**: o alias de SSH não respondeu. Verifique se o `Host` do
  host existe em `~/.ssh/config.local` (`ssh -G <alias>` mostra o usuário que
  seria usado) e se a VPN está de pé. O coletor tenta `<alias>` e `<alias>-local`.
- **`github: ausente` ou PRs vazios num repo que tem PR**: `gh auth status`.
- **`vault-lint: tem achado`** em `## avisos` é aviso por decisão, não erro.
  Não gaste a resposta com isso a menos que o dono pergunte.
