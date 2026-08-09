#!/bin/bash
# shellcheck shell=bash
#
# Fonte única dos MCP servers expostos ao Claude Code, espelhando os servers
# habilitados em opencode/opencode.json. Sourced por hooks/check.sh (só usa as
# chaves/nomes) e hooks/setup.sh (usa nome + JSON para registrar).
#
# Mantido como mapa bash (não um arquivo stowado) porque o Claude Code guarda a
# config MCP de escopo 'user' dentro de ~/.claude.json — arquivo com estado
# (histórico de sessão, trust de projeto) que não é seguro symlinkar inteiro.
#
# $GITHUB_TOKEN no valor de [github] abaixo é literal de propósito (aspas
# simples): headersHelper roda esse echo no momento da conexão, expandindo a
# variável no ambiente do Claude Code (vinda de ~/.bashrc.local), não aqui.
#
# 'sqlite' fica de fora: no opencode.json ele usa um path por-workspace
# (${workspaceFolder}/data/metadata.db), que não faz sentido como registro
# global de escopo 'user' no Claude Code.
#
# 'obsidian' precisa do `--with 'mcp<2'`: o mcp-obsidian 0.2.2 declara a
# dependência do SDK Python solta, então o uvx resolve o `mcp` 2.x, que removeu
# os decorators lowlevel `Server.list_tools`/`call_tool`. Sem o pin o server
# estoura AttributeError no import e o cliente só vê "Connection closed".
# Lembrando que ele fala com o plugin Local REST API, que roda DENTRO do app do
# Obsidian: com o Obsidian fechado não há nada escutando em 127.0.0.1:27124 e
# as tools falham mesmo com o pin correto.
#
# 'ssh' aponta pro clone local em ~/mcp-servers/mcp-ssh (não é pacote npm
# publicado, foi clonado e buildado manualmente com `npm run build`). $HOME
# abaixo é literal de propósito (aspas duplas): expande aqui mesmo, no
# ambiente de quem roda o hook, já que o valor precisa virar path absoluto
# antes de ir pro JSON registrado no Claude Code.

declare -A CLAUDE_MCP_SERVERS
# shellcheck disable=SC2034  # consumido por hooks/check.sh e hooks/setup.sh via source
# shellcheck disable=SC2016  # $GITHUB_TOKEN é literal de propósito (expande no headersHelper)
CLAUDE_MCP_SERVERS=(
  [git]='{"type":"stdio","command":"npx","args":["-y","git-mcp"]}'
  [docker]='{"type":"stdio","command":"npx","args":["-y","docker-mcp"]}'
  [github]='{"type": "http", "url": "https://api.githubcopilot.com/mcp/", "headersHelper": "echo \"{\\\"Authorization\\\": \\\"Bearer $GITHUB_TOKEN\\\"}\""}'
  [obsidian]='{"type":"stdio","command":"uvx","args":["--with","mcp<2","mcp-obsidian"]}'
  [ssh]="{\"type\":\"stdio\",\"command\":\"node\",\"args\":[\"$HOME/mcp-servers/mcp-ssh/dist/index.js\"]}"
)
