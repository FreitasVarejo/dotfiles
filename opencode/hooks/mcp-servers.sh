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

declare -A CLAUDE_MCP_SERVERS
# shellcheck disable=SC2034  # consumido por hooks/check.sh e hooks/setup.sh via source
# shellcheck disable=SC2016  # $GITHUB_TOKEN é literal de propósito (expande no headersHelper)
CLAUDE_MCP_SERVERS=(
  [git]='{"type":"stdio","command":"npx","args":["-y","git-mcp"]}'
  [docker]='{"type":"stdio","command":"npx","args":["-y","docker-mcp"]}'
  [github]='{"type": "http", "url": "https://api.githubcopilot.com/mcp/", "headersHelper": "echo \"{\\\"Authorization\\\": \\\"Bearer $GITHUB_TOKEN\\\"}\""}'
  [obsidian]='{"type":"stdio","command":"uvx","args":["mcp-obsidian"]}'
)
