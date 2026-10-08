#!/bin/bash
# shellcheck shell=bash
#
# Base comum dos hooks do pacote 'agents' (check.sh, setup.sh, build-web-zip.sh):
# onde ficam skills, MCPs e permissões no repo, e onde cada agente os lê.
#
# O pacote não é stowado. Nada nele espelha $HOME: as skills são linkadas uma a
# uma pelo setup.sh, e MCPs e permissões são mesclados em arquivos que os
# agentes também escrevem (~/.claude.json, ~/.claude/settings.json,
# ~/.cursor/*.json), e que por isso nunca podem ser symlink para o repo.

# `pwd -P`: o caminho FÍSICO. Os links são comparados via `readlink -f` e
# `realpath`, que resolvem symlinks; com o repo atrás de um symlink
# (~/dotfiles -> ~/dev/dotfiles), o caminho lógico nunca bateria.
AGENTS_PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck disable=SC2034  # consumido pelos hooks via source
AGENTS_SKILLS_DIR="$AGENTS_PKG_DIR/skills"
AGENTS_MCP_DIR="$AGENTS_PKG_DIR/mcp"
# shellcheck disable=SC2034  # consumido pelos hooks via source
AGENTS_DENY_FILE="$AGENTS_PKG_DIR/permissions/deny.json"
AGENTS_CONFIG_PY="$AGENTS_PKG_DIR/hooks/agent_config.py"

# Diretórios de onde os agentes leem skills de nível usuário. O Cursor CLI lê
# o mesmo ~/.claude/skills (ADR 0003), então uma entrada serve aos dois; agente
# novo que leia de outro lugar entra aqui com uma linha.
# shellcheck disable=SC2034  # consumido pelos hooks via source
AGENT_SKILL_DIRS=("$HOME/.claude/skills")

# Para onde o claude.ai sincroniza as skills que subiram por zip (ADR 0010).
# shellcheck disable=SC2034  # consumido pelos hooks via source
CLAUDE_SYNCED_SKILLS_DIR="$HOME/.claude/skills/synced"

# Onde as skills moravam quando o pacote se chamava 'claude' e era stowado.
# Links para cá ficaram pendurados com a mudança; o setup.sh os refaz.
# shellcheck disable=SC2034  # consumido pelos hooks via source
AGENTS_LEGACY_SKILLS_DIR="$(dirname "$AGENTS_PKG_DIR")/claude/.claude/skills"

# Config de MCP de escopo user de cada agente. A do Claude Code é lida direto,
# e não pela saída de `claude mcp list`, por dois motivos: o `list` imprime nome
# e status, nunca a CONFIGURAÇÃO (respondia "existe?" mas não "está em dia?"), e
# ele health-checka cada servidor, pondo a rede no meio de uma pergunta local.
# shellcheck disable=SC2034  # consumido pelos hooks via source
CLAUDE_MCP_CONFIG="${CLAUDE_MCP_CONFIG:-$HOME/.claude.json}"
# shellcheck disable=SC2034  # consumido pelos hooks via source
CLAUDE_SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
CURSOR_HOME="${CURSOR_HOME:-$HOME/.cursor}"
# shellcheck disable=SC2034  # consumido pelos hooks via source
CURSOR_MCP_CONFIG="$CURSOR_HOME/mcp.json"
# shellcheck disable=SC2034  # consumido pelos hooks via source
CURSOR_CLI_CONFIG="$CURSOR_HOME/cli-config.json"

# load_mcp_servers — preenche MCP_SERVERS[nome] = JSON (compacto), um por
# arquivo em mcp/, nome = basename. Este conjunto É a lista do que faz parte do
# workflow: MCP registrado à mão e ausente daqui é experimento local, sem
# healthcheck nem reprodução (ADR 0011). O porquê de cada servidor está em
# mcp/README.md. Quem lê os arquivos é o agent_config.py (troca ${HOME}, aceita
# qualquer formatação); falha = arquivo do repo inválido, e a mensagem já saiu.
# shellcheck disable=SC2034  # consumido pelo setup.sh via source
declare -A MCP_SERVERS
load_mcp_servers() {
  local name json out
  out=$(agent_config mcp-servers "$AGENTS_MCP_DIR") || return 1
  while IFS=$'\t' read -r name json; do
    # shellcheck disable=SC2034  # consumido pelo setup.sh via source
    [[ -n "$name" ]] && MCP_SERVERS["$name"]="$json"
  done <<<"$out"
}

# agent_config <subcomando> <args...> — ver o docstring de agent_config.py.
# Quem chama SEMPRE confere o status: saída vazia de um script que caiu se
# parece com "nada a fazer", o pior jeito de falhar aqui. Saída 2 = arquivo do
# repo inválido, 3 = arquivo do agente ilegível; a mensagem vai para stderr.
agent_config() {
  python3 "$AGENTS_CONFIG_PY" "$@"
}

# skill_surfaces <skill-dir> -> imprime o valor de metadata.surfaces do SKILL.md
# ("code", "web" ou "code,web"; vazio se não declarado).
skill_surfaces() {
  sed -n '/^---$/,/^---$/p' "$1/SKILL.md" | sed -n 's/^  surfaces: *"\{0,1\}\([a-z,]*\)"\{0,1\}.*/\1/p' | head -n1
}

# package_skills — nome de cada skill do pacote, uma por linha, ordenado.
package_skills() {
  find "$AGENTS_SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}
