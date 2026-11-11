---
description: Confere sozinho se o OpenCode deste computador está como os dotfiles declaram e diz o que passou, com a evidência
---

Você vai conferir este OpenCode contra o que o repo dos dotfiles declara e relatar cada item como PASSOU, FALHOU ou NÃO TESTADO, sempre com a evidência (o comando que rodou e o que viu, ou o trecho do contexto que citou). Você é o teste: não conserte nada, não "ajuste para passar". O que falhar, relate com a mensagem literal.

Regras do comando, valem do começo ao fim:

- Só ferramentas nativas: shell, read, grep, glob, skill e subagent. Nada de MCP, nada de instalar coisa, nada de rede.
- Só leitura. A única escrita é o canário do item 7, que você apaga no fim. Nada dentro do repo dos dotfiles muda.
- Os pedidos de permissão em shell são esperados: o dono aprova. Se um pedido não aparecer onde se esperava, ou aparecer onde não se esperava, isso é achado.
- NUNCA teste o deny lendo arquivo de segredo (credencial, token, `hosts.yml`, `.bashrc.local`, nada parecido), nem "só para ver se bloqueia". O canário do item 7 é o único teste de deny.
- A saída de `opencode debug config` pode trazer valores sensíveis (chave de API, token, cabeçalho, endereço de proxy). Compare só o que o item pede e nunca copie desses valores na resposta.
- Medição só por contagem e presença (item 10): nada de nome de repo, de pasta do trabalho ou de caminho fora de `~/.config/opencode` e do repo dos dotfiles.

## 0. Onde está o repo

Descubra o diretório de config com `opencode debug paths config`. O comando `conferir.md` desse diretório é um symlink para o repo dos dotfiles: `readlink -f` nele dá `<repo>/agents/opencode/commands/conferir.md`, e `<repo>` é o que vem antes de `/agents/opencode/`. Daqui em diante `<repo>` e `<config>` são esses dois caminhos. Se o symlink não existir, o `./setup.sh` não rodou neste computador: marque FALHOU, procure o repo em `~/dotfiles` e siga com ele.

## 1. Versão

`opencode --version` tem de começar com `2.`. Registre a versão e, do repo, o commit (`git -C <repo> rev-parse --short HEAD`) e quantos arquivos o clone tem modificados (`git -C <repo> status --short`, só a contagem).

## 2. healthcheck

Rode `<repo>/healthcheck.sh`. PASSOU se sair com código 0. Registre o código e, literais, as linhas com `[WARN]`, `[MISSING]` e `[ERROR]`. Sem elas, diga "nenhuma".

## 3. Arquivos gerados e config em dia

Rode `python3 -I <repo>/agents/hooks/agent_config.py opencode-plan <config> <repo>/agents "$(hostname -s)"`. Saída vazia = PASSOU. Cada linha é algo que o repo declara e a config não tem (chave do `opencode.json`, arquivo de `agents/` ou `commands/`): FALHOU, com as linhas literais. Veja também se existe `<config>/modelos.json`; ele é por computador e fica fora do repo. Sem ele, os subagentes herdam o modelo da sessão (anote como achado, não como falha).

## 4. O que o OpenCode enxerga: config e agentes

Rode `opencode debug config` e `opencode debug agents` e compare com o que o repo declara (`<repo>/agents/opencode/config.json`, `<repo>/agents/permissions/deny.json`, `<repo>/agents/subagents/*.md`). Mostre, para cada item, "declarado × visto":

- `share` é `disabled`.
- As `instructions` incluem o caminho de `<repo>/agents/instructions/user.md` e, se `<repo>/agents/instructions/machines/<hostname>.md` existir, o dele.
- Em `permissions`, o bloco do repo está inteiro, contíguo e no FIM da lista, na ordem do `config.json`. O que o computador tem a mais antes dele não é falha.
- Em `policies`, cada entrada do `deny.json` aparece traduzida como `tool.use` com `deny` (caminho vira `read:*...` ou `edit:*...`, shell vira `shell:...`), mais a do canário.
- Os agentes `auditor`, `coletor-web`, `explore` e `implementador` existem com `mode` de subagente. A cor é `#RRGGBB`. O `model` bate com `<config>/modelos.json` quando o arquivo existe e a chave do subagente (`opus`, `sonnet`, `haiku`) está nele; para `model: inherit` não há `model`.
- O `auditor` tem a regra de negar tudo (`*` com `deny`) antes das regras que devolvem `read`, `grep`, `glob` e `shell`, e não devolve `edit`.

## 5. Skills

As skills que você enxerga (a lista da ferramenta skill, no seu contexto) contra `ls ~/.claude/skills`. Cada skill de `<repo>/agents/skills/` tem de estar na lista, exceto as que têm `disable-model-invocation: true` no `SKILL.md` (essas saem só da lista automática). Falta ou sobra: FALHOU, com os nomes. Depois carregue a skill `grilling` pela ferramenta skill; PASSOU se o conteúdo chegou. Não resuma o que carregou.

## 6. Instrução de usuário

Sem ler arquivo nenhum antes: cite do seu próprio contexto a primeira linha de regra da instrução de usuário que você recebeu (ela vem de `<repo>/agents/instructions/user.md`, pela chave `instructions`) e diga de que arquivo o contexto diz que veio. Só então leia `<repo>/agents/instructions/user.md` e compare. PASSOU se a linha citada está no arquivo. Se você não achar a instrução no contexto, FALHOU: a chave `instructions` não chegou.

## 7. Canário do deny, de dentro e de fora do diretório da sessão

O repo declara um deny só do OpenCode sobre o nome de arquivo `canario-do-deny-opencode`, para provar o mecanismo sem tocar em segredo.

1. Crie, pelo shell, `canario-do-deny-opencode` no diretório da sessão e `controle-do-deny-opencode` ao lado dele, ambos com a linha `conteudo-inofensivo`. Crie outro par dentro de um diretório novo de `mktemp -d`, fora do diretório da sessão.
2. Com a ferramenta read (nunca `cat` nem shell), leia o controle de dentro e o controle de fora: tem de funcionar. Isso prova que a leitura em geral funciona.
3. Com a ferramenta read, tente ler o canário de dentro e o de fora. PASSOU em cada um se a leitura foi recusada pela regra de deny (mensagem de permissão negada) e a linha `conteudo-inofensivo` não apareceu. Se o OpenCode perguntar antes, é o pedido de acesso ao diretório de fora: o dono aprova, e a leitura ainda tem de ser recusada. Se a linha aparecer, FALHOU e é o achado mais grave da conferência.
4. Apague os quatro arquivos e o diretório temporário. Confirme que sumiram.

## 8. Um subagente de verdade

Chame o subagente `auditor` com a ferramenta subagent e este pedido: "Liste os três primeiros arquivos de `<repo>/agents/subagents`, diga o seu nome de agente e depois tente criar o arquivo `auditor-nao-deve-criar` no diretório atual com a ferramenta de escrita (write ou edit, nunca o shell), para provar que a edição está fechada; relate a resposta literal da tentativa." PASSOU se ele respondeu, listou os arquivos e a criação foi recusada sem virar pergunta de permissão. Se ele tentar pelo shell, o pedido de permissão que aparecer é esperado: recuse-o e repita a instrução. Se o arquivo foi criado, apague-o e marque FALHOU.

## 9. Comandos gerados e linkados

Liste `<config>/commands`. Os dois comandos escritos à mão (`conferir.md` e `lacunas.md`) têm de ser symlinks para o repo, e cada arquivo sem ser symlink tem de ter a linha `<!-- gerado por agents/hooks/agent_config.py`. Diga quantos há de cada tipo e aponte o que não é nenhum dos dois. Só a contagem e os nomes dos comandos (não há conteúdo do trabalho neles).

## 10. Medição (só contagem e presença)

- hostname (`hostname`), como está;
- memória: total e usada, em MB (`free -m`), e quantos processos `opencode` há agora;
- `XDG_RUNTIME_DIR`: definida ou não, e se o diretório existe (sem imprimir o caminho);
- o vault `~/ObsidianVault`: existe ou não, e se tem `.freitask/` dentro (sim ou não);
- quantos repos fora do repo dos dotfiles têm `docs/agents/verificacao.md`: `find ~ -maxdepth 5 -path '*/docs/agents/verificacao.md' -not -path '<repo>/*' 2>/dev/null | wc -l`, e só o número vai para a resposta, nunca a lista.

## 11. O que só o dono testa

Termine com esta lista, como está, para o dono executar à mão (você não consegue): a skill chamada com `@` e pelo `/skills`; um comando gerado (por exemplo `/verificar`) abrindo a sessão-filha; o pedido de permissão em `shell` e em `edit` (um comando fora da lista liberada e um arquivo novo); o peso na máquina durante o uso (memória e CPU com a sessão aberta e com um subagente rodando). Cada um, com o caminho infeliz: o que acontece quando recusa, quando o provedor cai, quando o proxy barra.

## Formato da resposta

Uma linha de resumo no topo ("N passaram, N falharam, N não testados"), depois os itens de 1 a 10 na ordem, cada um com o veredito e a evidência, depois o item 11. Se algo falhou ou se o dono notou alguma lacuna contra o Claude Code, sugira rodar `/lacunas` nesta mesma sessão, que usa este resultado.
