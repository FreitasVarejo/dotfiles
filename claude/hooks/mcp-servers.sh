#!/bin/bash
# shellcheck shell=bash
#
# Fonte única dos MCP servers expostos ao Claude Code. Sourced por
# hooks/check.sh (só usa as chaves/nomes) e hooks/setup.sh (usa nome + JSON
# para registrar). Este mapa É a lista do que faz parte do workflow: MCP
# registrado à mão numa máquina e ausente daqui é experimento local, sem
# healthcheck nem reprodução (ADR 0011 do projeto workflow-ia, no vault).
#
# Mantido como mapa bash (não um arquivo stowado) porque o Claude Code guarda a
# config MCP de escopo 'user' dentro de ~/.claude.json — arquivo com estado
# (histórico de sessão, trust de projeto) que não é seguro symlinkar inteiro.
#
# $GITHUB_TOKEN no valor de [github] abaixo é literal de propósito (aspas
# simples): headersHelper roda esse echo no momento da conexão, expandindo a
# variável no ambiente do Claude Code (vinda de ~/.bashrc.local), não aqui.
#
# Não há MCP de Obsidian local: onde o vault está em disco, o agente lê e
# escreve os .md direto. O único MCP de Obsidian é o obsidian-web-mcp do pi01,
# para o claude.ai, que não tem disco (ADR 0008).
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
  [ssh]="{\"type\":\"stdio\",\"command\":\"node\",\"args\":[\"$HOME/mcp-servers/mcp-ssh/dist/index.js\"]}"
)

# Diretório de skills do pacote e o alvo do stow. Compartilhado pelos hooks
# para que "quais skills existem" tenha uma resposta só.
# shellcheck disable=SC2034  # consumido pelos hooks via source
CLAUDE_PKG_SKILLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.claude/skills" && pwd)"
# shellcheck disable=SC2034  # consumido pelos hooks via source
CLAUDE_HOME_SKILLS_DIR="$HOME/.claude/skills"

# skill_surfaces <skill-dir> -> imprime o valor de metadata.surfaces do SKILL.md
# ("code", "web" ou "code,web"; vazio se não declarado).
skill_surfaces() {
  sed -n '/^---$/,/^---$/p' "$1/SKILL.md" | sed -n 's/^  surfaces: *"\{0,1\}\([a-z,]*\)"\{0,1\}.*/\1/p' | head -n1
}
