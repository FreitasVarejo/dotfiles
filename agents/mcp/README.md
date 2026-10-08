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

**MCP só entra onde o shell não alcança** (ADR 0025). git, GitHub, ssh e Docker
vão pela CLI (`git`, `gh`, `ssh`, `docker`), que o agente já roda pelo shell.
Os MCPs que só embrulhavam essas CLIs saíram, e o `check.sh` avisa enquanto
algum deles continuar registrado numa máquina.

O JSON não aceita comentário, então o porquê fica aqui:

- **`playwright`** dá ao agente um navegador (Chromium headless, perfil
  isolado). Isso o shell não oferece. A versão fica fixa porque cada uma pede a
  sua revisão do Chromium, que precisa estar baixada na máquina:

  ```bash
  /usr/bin/npx -y -p @playwright/mcp@0.0.83 playwright install chromium
  ```

  Quem trocar a versão no JSON troca também neste comando. O `command` é
  `/usr/bin/npx`, e não `npx`, porque o wrapper do nvm quebra fora de shell
  interativo. O viewport fica no default: um projeto que precise de outro (o
  bjj-vision usa 390×844) declara um `playwright` no `.mcp.json` dele, e o
  escopo de projeto vence o de user.
- **`${HOME}`** é o único placeholder. O `lib.sh` o troca pelo `$HOME` de quem
  roda o hook, porque o agente precisa de path absoluto. Nada mais é expandido.
- **Chave só do Claude Code** (hoje, `headersHelper`): um servidor que dependa
  dela **não** vai para o Cursor, porque lá subiria sem ela. O setup avisa e pula.
- **Não há MCP de Obsidian local.** Onde o vault está em disco, o agente lê e
  escreve os `.md` direto. O único MCP de Obsidian é o `obsidian-web-mcp` do
  pi01, para o claude.ai, que não tem disco (ADR 0008).
- No Cursor, o `type` sai do JSON. O Cursor deduz o transporte de `command`
  (stdio) ou de `url` (http).
