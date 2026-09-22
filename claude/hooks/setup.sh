#!/bin/bash
# shellcheck shell=bash
# Setup do pacote 'claude' (roda após o stow):
#   - garante que só as skills são symlink, nunca ~/.claude/skills inteiro;
#   - registra os MCP servers do mapa no Claude Code (escopo user).

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"
# shellcheck source=./mcp-servers.sh
. "$(dirname "${BASH_SOURCE[0]}")/mcp-servers.sh"

# Numa máquina nova ~/.claude/skills não existe, e o stow "dobra": symlinka o
# diretório inteiro para dentro do repo. Aí o Claude Code escreveria synced/
# (skills sincronizadas do claude.ai) dentro dos dotfiles. Desdobra: tira o
# pacote, cria o diretório de verdade e stowa de novo — agora skill por skill.
unfold_skills_dir() {
  [[ -L "$CLAUDE_HOME_SKILLS_DIR" ]] || return 0
  log_warn "\$HOME/.claude/skills veio dobrado pelo stow; desdobrando para skill por skill..."
  (cd "$DOTFILES_DIR" && stow -D -t "$HOME" claude)
  mkdir -p "$CLAUDE_HOME_SKILLS_DIR"
  if (cd "$DOTFILES_DIR" && stow -t "$HOME" claude); then
    log_success "\$HOME/.claude/skills é diretório real; skills linkadas uma a uma"
  else
    log_warn "Falha ao re-stowar o pacote 'claude'"
  fi
}

register_claude_mcp_servers() {
  if ! command -v claude &>/dev/null; then
    log_warn "claude não encontrado, pulando registro de MCP servers"
    return
  fi

  if ! command -v python3 &>/dev/null; then
    log_warn "python3 não encontrado; não dá para comparar o registro com o mapa."
    return
  fi

  local name plan
  plan=$(
    for name in "${!CLAUDE_MCP_SERVERS[@]}"; do
      printf '%s\t%s\n' "$name" "${CLAUDE_MCP_SERVERS[$name]}"
    done | mcp_plan
  )

  local verdict
  while IFS=$'\t' read -r name verdict; do
    [[ -n "$name" ]] || continue
    case "$verdict" in
      ok)
        log_success "MCP server '$name' já registrado e em dia"
        continue
        ;;
      invalid)
        log_warn "MCP server '$name': JSON inválido em mcp-servers.sh"
        continue
        ;;
      update)
        # `add-json` não sobrescreve servidor existente: atualizar é remover e
        # registrar de novo. A remoção é tolerante a falha de propósito — se o
        # servidor sumiu entre o plano e aqui, o add seguinte resolve.
        claude mcp remove "$name" --scope user &>/dev/null || true
        ;;
    esac
    if claude mcp add-json "$name" "${CLAUDE_MCP_SERVERS[$name]}" --scope user &>/dev/null; then
      if [[ "$verdict" == "update" ]]; then
        log_success "MCP server '$name' atualizado no Claude Code (configuração havia mudado)"
      else
        log_success "MCP server '$name' registrado no Claude Code"
      fi
    else
      log_warn "Falha ao registrar MCP server '$name' no Claude Code"
    fi
  done <<<"$plan"
}

log_info "Conferindo o diretório de skills..."
unfold_skills_dir

echo ""
log_info "Registrando MCP servers do Claude Code..."
register_claude_mcp_servers
