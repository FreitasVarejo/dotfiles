# MCP servers do workflow

Um arquivo por servidor: `<nome>.json` é a config na forma do Claude Code, em
qualquer formatação, e o nome do arquivo vira o nome do servidor. O
`agents/hooks/setup.sh` registra cada um no Claude Code (`claude mcp add-json`,
escopo user) e mescla no
`~/.cursor/mcp.json` quando o Cursor está na máquina. O `check.sh` compara os
dois com o repo.

Este diretório é a lista do que faz parte do workflow. MCP registrado à mão numa
máquina e ausente daqui é experimento local, sem healthcheck nem reprodução, e o
setup não o remove (ADR 0011 do projeto workflow-ia, no vault). Para promover,
basta um arquivo aqui e um ADR dizendo por quê.

O JSON não aceita comentário, então o porquê fica aqui:

- **`${HOME}`** é o único placeholder. O `lib.sh` o troca pelo `$HOME` de quem
  roda o hook, porque o agente precisa de path absoluto. Nada mais é expandido.
- **`github`**: o header vem de um `headersHelper` que roda `gh auth token` no
  momento da conexão. O segredo fica em `~/.config/gh/hosts.yml`, lido sob
  demanda, em vez de ir para um `export GITHUB_TOKEN`, que todo processo filho
  herda, agentes incluídos. Um `env` num transcript bastava para vazá-lo.
  `headersHelper` só existe no Claude Code, então o setup **não** leva este
  servidor para o Cursor e avisa. Como autenticá-lo lá sem exportar o token é
  pendência.
- **`ssh`** aponta para um clone local em `~/mcp-servers/mcp-ssh`, que não é
  pacote npm publicado: foi clonado e buildado à mão com `npm run build`.
- **Não há MCP de Obsidian local.** Onde o vault está em disco, o agente lê e
  escreve os `.md` direto. O único MCP de Obsidian é o `obsidian-web-mcp` do
  pi01, para o claude.ai, que não tem disco (ADR 0008).
- No Cursor, o `type` sai do JSON. O Cursor deduz o transporte de `command`
  (stdio) ou de `url` (http).
