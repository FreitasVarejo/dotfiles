---
description: Cola do Claude Code para o OpenCode (rewind, comandos e teclas), sem chamar ferramenta
---

Responda com a cola abaixo, como está, sem chamar nenhuma ferramenta e sem comentar. Se `$ARGUMENTS` vier preenchido, mostre só as linhas que tratam disso.

Medido no OpenCode 2.2.7 em 17/11/2026, com o `cli.json` e o plugin de apelidos dos dotfiles. A tecla líder é `ctrl+x`: `<leader>g` é `ctrl+x` e depois `g`. Os chats ficam sem barra de abas: um por pane.

## Rewind

| Claude Code | OpenCode |
|---|---|
| Esc Esc ou `/rewind`, conversa e código | `/rewind` (apelido de `/timeline`, `<leader>g`; só dentro de uma sessão), escolha a mensagem e depois **Revert** |
| rewind só da conversa | `/rewind`, escolha a mensagem e depois **Fork** (sessão nova; os arquivos ficam como estão) |
| rewind só do código | não há |
| desfazer a última mensagem | `/undo` (`<leader>u`); `/redo` (`<leader>r`) volta atrás enquanto nada novo foi enviado |

O revert depende dos snapshots da config; não os desligue.

## Comandos com outro nome

| Claude Code | OpenCode |
|---|---|
| `/resume`, `/continue` | funcionam (apelidos de `/sessions`) |
| `/effort` | funciona (apelido de `/variants`) |
| `/clear` | `/clear` ou `/new` (`<leader>n`) |
| `/model` | funciona (apelido de `/models`, `<leader>m`) |
| `/config` | funciona (apelido de `/settings`) |
| `/mcp`, `/plugin` | funcionam (apelidos de `/mcps`, `/plugins`) |
| `/cost` | funciona, mas abre `/stats` (tokens e sessões, sem custo em dinheiro); `/usage` mostra os limites do OpenCode Console |
| `/theme` | funciona (apelido de `/themes`) |
| `/login` | funciona (apelido de `/connect`) |
| `/add-dir` | não há; `/cd` troca a pasta da sessão |
| `/btw` | `/btw` |
| Shift+Tab | Shift+Tab troca de agente (build e plan) |
| `ctrl+g` (editor) | `<leader>e` |

## Subagentes

Com o prompt vazio: `ctrl+↓` abre a lista (o `↓` só abre no modo NORMAL do vim; no INSERT o plugin de vim o toma para mover o cursor), `←` e `→` passam de um para o outro, `↑` volta para a conversa principal. Na lista, Enter entra e `ctrl+d` interrompe.

## Teclas que os dotfiles mudaram

`ctrl+↓` abre a lista de subagentes (o `↓` continua valendo); `ctrl+o` cicla a verbosidade da transcrição; `<leader>o` abre o menu de sessões e projetos; `ctrl+c` interrompe (dois toques com o modelo rodando) e, parado, limpa o prompt e depois sai.
