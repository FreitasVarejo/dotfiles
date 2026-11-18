---
name: research
description: Guarda e reaproveita pesquisa no vault do Obsidian. Antes de pesquisar um assunto (busca na web, deep research ou leitura do disco), consulta o que já foi respondido em ~/ObsidianVault/research/; ao terminar o assunto, grava o bruto e a nota com `triagem: pendente`, sem esperar OK, e a triagem roteia depois cada pergunta aberta (decidida, task ou descartada). Use sempre que a conversa for pesquisar algo ou acabar de pesquisar, quando chegar um relatório de deep research, quando o dono mandar triar uma pesquisa pendente ou fizer uma pergunta que cruza pesquisas, ou quando perguntar se já pesquisou um assunto — mesmo que ele não diga "skill" nem "research".
metadata:
  surfaces: "code,web"
---

# Pesquisa no vault

Pesquisa respondida mora em `~/ObsidianVault/research/<assunto>/`, uma pasta
por assunto, fora de qualquer task. Esta skill é o ritual: consultar antes,
gravar no fim, triar depois. O porquê e as alternativas recusadas: ADR 0040
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
- **A pergunta cruza pastas** ("o que as pesquisas dizem sobre X?"): é a
  pesquisa transversal, na seção 5.

## 2. Pesquisar: a coleta vai para o `coletor-web`

No Claude Code, buscar na web e ler o que voltou é **coleta**: a sessão
despacha o subagente `coletor-web` e deixa o `WebSearch` e o `WebFetch` com
ele. Frentes independentes vão uma por subagente, em paralelo. O pedido leva a
pergunta, o que a consulta já achou e o que falta.

**Deep research leva o que já se sabe.** Quando a pesquisa vai para deep
research, o prompt carrega a conclusão vigente das notas que a consulta achou e
avisa a ferramenta de que ela não tem acesso ao vault.

O relatório que volta é o bruto da rodada. A conclusão e a triagem são da
sessão: ela lê o relatório e confere na fonte o achado de que a conclusão
depende. A leitura de código ou do disco é do `Explore`.

## 3. Ao fim do assunto: grave

Fim do assunto, não do chat: a pergunta foi respondida, ou o dono passou a
outra coisa. Grave sem esperar OK (bruto, depois `index.md`, seção 4) e diga ao
dono em uma linha a pasta e que a nota ficou `triagem: pendente`.

- a pasta: `research/<assunto>/`, em kebab-case, nova ou a que a consulta achou;
- a linha `pergunta:`;
- a conclusão vigente, em poucas linhas, marcada como do agente até a triagem
  (seção 4);
- as perguntas que ficaram abertas, uma por linha.

## 4. O que gravar

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
triagem: pendente           # pendente | feita
pergunta: "<uma linha>"
---
```

Sem tags. A skill grava `pendente`; só a triagem (seção 6) troca por `feita`.
O corpo, nesta ordem:

- `# <Assunto>`
- `## Conclusão vigente`: o que vale hoje, inclusive "não vale a pena". Com
  `triagem: pendente`, a primeira linha é `> Conclusão do agente, ainda não
  triada.`
- `## Pergunta`: como o dono fez.
- `## Prompt`: só quando houve deep research.
- `## Perguntas abertas`: uma por linha, enquanto a triagem não vem.
- `## Triagem do dono`: o que ele reconheceu e o que descartou, escrito na
  triagem.
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

## 5. Pergunta transversal

Pergunta que cruza pastas vira pesquisa própria, sem bruto novo:

1. `grep` das `pergunta:` e leia os `index.md` que cobrem a pergunta; leia os
   brutos só se a conclusão não bastar.
2. Responda e grave em `research/<pergunta>/index.md` (formato da seção 4,
   `triagem: pendente` como em toda nota do agente; sem `## Prompt` e com a
   `## Rodada` apontando as notas citadas no lugar do bruto), citando-as com
   caminho.
3. Sem camada de conceito e sem links "Relacionadas": a ligação é a citação
   dentro da resposta.

## 6. Triagem

O dono pede a triagem de uma pesquisa, ou escolhe uma da lista
`grep -l '^triagem: pendente' ~/ObsidianVault/research/*/index.md` (no
claude.ai, a busca do conector por `triagem: pendente`). Comece pela mais
velha. Cada pergunta aberta sai com um destino, na hora:

- **decidida:** a decisão entra na conclusão ou em `## Triagem do dono`;
- **vira task:** abra pela skill `freitask` e cite a task na linha;
- **descartada:** diga em uma linha por quê.

Pronta quando `## Perguntas abertas` só tem linhas "virou
`[[projects/<projeto>/tasks/<id>|<id>]]`" ou "descartada". Então tire a marca
da conclusão e troque o campo por `triagem: feita`.

## 7. Os dois canais

### Claude Code, no disco

- Bruto que chegou como arquivo: copie com `cp` e confira com `cmp`. Não o
  reescreva pelo modelo.
- Bruto que só existe na conversa: grave o texto integral.
- Re-pesquisa: edite o `index.md`; o bruto antigo fica como está. A rodada nova
  deixa `triagem: pendente`.

### claude.ai, pelo `obsidian-web-mcp`

- Sem shell: tudo passa pelas ferramentas do conector. Gravar o bruto é
  reemitir o anexo inteiro.
- Consulta, pergunta transversal e lista de pendentes: a busca do conector por
  frontmatter (`tipo: pesquisa`, `triagem: pendente`), lendo cada `index.md`
  achado. A task da triagem sai pela skill `freitask`, que também roda aqui.
- Confira pelo tamanho em bytes: o que o conector informa do arquivo gravado
  contra o tamanho do anexo. Se não bater, ou se o conector não informar,
  diga isso ao dono e não grave a nota até ele decidir.

## Nunca

- Esperar OK do dono para gravar o bruto e o `index.md`.
- Gravar `triagem: feita` com pergunta ainda aberta no `index.md`.
- Editar um `bruto-*.md` que já existe.
- Criar `~/ObsidianVault/research/` onde ela não existe.
- Pôr a pesquisa no corpo de uma task.
- Guardar fonte web transcrita em `research/`: fonte que vale guardar é item do
  Karakeep.

As regras do vault, inclusive as de pesquisa: `~/ObsidianVault/AGENTS.md`.
