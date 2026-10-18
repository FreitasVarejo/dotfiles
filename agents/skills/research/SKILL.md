---
name: research
description: Guarda e reaproveita pesquisa no vault do Obsidian. Antes de pesquisar um assunto (busca na web, deep research ou leitura do disco), consulta o que já foi respondido em ~/ObsidianVault/research/; ao terminar o assunto, propõe a nota da pesquisa e só grava com OK do dono. Use sempre que a conversa for pesquisar algo ou acabar de pesquisar, quando chegar um relatório de deep research, ou quando o dono perguntar se já pesquisou um assunto — mesmo que ele não diga "skill" nem "research".
metadata:
  surfaces: "code,web"
---

# Pesquisa no vault

Pesquisa respondida mora em `~/ObsidianVault/research/<assunto>/`, uma pasta
por assunto, fora de qualquer task. Esta skill é o ritual em duas pontas:
consultar antes, propor no fim. O porquê e as alternativas recusadas: ADR 0040
em `~/ObsidianVault/projects/workflow-ia/decisoes/supersedidas/`.

**Se `~/ObsidianVault/research/` não existe nesta máquina, não crie.** Diga que
aqui não há onde guardar e siga só com a pesquisa.

## 1. Antes de pesquisar: consulte

No Claude Code:

```bash
grep -H '^pergunta:' ~/ObsidianVault/research/*/index.md
```

No claude.ai, é a busca do conector por frontmatter `tipo: pesquisa`.

- **Uma pergunta cobre o assunto:** leia o `index.md` dela e parta da conclusão
  vigente. Diga ao dono o que já se sabe e de quando é, e pesquise só o que
  falta. O resultado vira rodada nova na mesma pasta.
- **Nenhuma cobre:** pesquise.

## 2. Ao fim do assunto: proponha

Fim do assunto, não do chat: a pergunta foi respondida, ou o dono passou a
outra coisa. Proponha numa mensagem só:

- a pasta: `research/<assunto>/`, em kebab-case, nova ou a que a consulta achou;
- a linha `pergunta:`;
- a conclusão vigente, em poucas linhas;
- a triagem do dono, o que ele reconheceu e o que descartou. Se a conversa não
  disse, pergunte junto.

**Grave só com OK.** Sem OK, nada vai para o disco: o OK é o filtro que separa
conversa de nota.

## 3. O que gravar

**Ordem: bruto primeiro, nota depois.** Se a segunda escrita falhar, sobra um
bruto sem nota, que se vê e se refaz.

### O bruto

- `bruto-AAAA-MM-DD.md`, com a data da rodada. O segundo do mesmo dia leva `-2`.
- É o relatório ou a saída **como veio**: sem frontmatter, sem edição. É sempre
  o anexo inteiro, nunca o resumo que o chat mostra, que perde as URLs.
- Depois de gravado, não se edita mais.
- Rodada sem relatório, como uma medição que cabe na própria rodada, não tem
  bruto.
- Relatório que já mora em outra pesquisa não se copia: a rodada aponta para ele.
- Outros anexos (CSV, print, log) ficam soltos na pasta, com nome descritivo.

### A nota: `index.md`

```yaml
---
tipo: pesquisa
status: vigente
data: AAAA-MM-DD            # a da primeira rodada; não muda na re-pesquisa
origem: "<onde e como foi feita>"
pergunta: "<uma linha>"
---
```

Sem tags. O corpo, nesta ordem:

- `# <Assunto>`
- `## Conclusão vigente`: o que vale hoje, inclusive "não vale a pena".
- `## Pergunta`: como o dono fez.
- `## Prompt`: só quando houve deep research.
- `## Triagem do dono`: o que ele reconheceu e o que descartou.
- `## Fontes principais`: de 3 a 5. **Só entra fonte cuja URL está no bruto**;
  confira no arquivo antes de listar.
- `## Rodada AAAA-MM-DD — <como foi feita>`: uma por rodada, com o ponteiro
  `Bruto: [[research/<assunto>/bruto-AAAA-MM-DD|bruto-AAAA-MM-DD]].`

### Re-pesquisa do mesmo assunto

Mesma pasta, bruto novo datado, `## Rodada` nova embaixo e a conclusão do topo
reescrita. Nunca pasta nova para o mesmo assunto.

### Citar

- A nota se cita com caminho: `[[research/<assunto>/index|<assunto>]]`.
- Pesquisa que serve a uma task: a nota cita a task
  (`[[projects/<projeto>/tasks/<id>|<id>]]`) e a task ganha uma linha que cita
  a nota. O conteúdo da pesquisa não entra no corpo da task.

## 4. Os dois canais

### Claude Code, no disco

- Bruto que chegou como arquivo: copie com `cp` e confira com `cmp`. Não o
  reescreva pelo modelo.
- Bruto que só existe na conversa: grave o texto integral.
- Re-pesquisa: edite o `index.md`; o bruto antigo fica como está.

### claude.ai, pelo `obsidian-web-mcp`

- Sem shell: tudo passa pelas ferramentas do conector. Gravar o bruto é
  reemitir o anexo inteiro.
- Confira pelo tamanho em bytes: o que o conector informa do arquivo gravado
  contra o tamanho do anexo. Se não bater, ou se o conector não informar,
  diga isso ao dono e não grave a nota até ele decidir.

## Nunca

- Gravar sem OK.
- Editar um `bruto-*.md` que já existe.
- Criar `~/ObsidianVault/research/` onde ela não existe.
- Pôr a pesquisa no corpo de uma task.
- Guardar fonte web transcrita em `research/`: fonte que vale guardar é item do
  Karakeep.

As regras do vault, inclusive as de pesquisa: `~/ObsidianVault/AGENTS.md`.
