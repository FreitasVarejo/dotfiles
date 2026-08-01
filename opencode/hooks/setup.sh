#!/bin/bash
# shellcheck shell=bash
# Setup do pacote 'opencode' (roda após o stow):
#   - registra os MCP servers no Claude Code (escopo user);
#   - instala o plugin Local REST API no ObsidianVault, se existir.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"
# shellcheck source=./mcp-servers.sh
. "$(dirname "${BASH_SOURCE[0]}")/mcp-servers.sh"

register_claude_mcp_servers() {
  if ! command -v claude &>/dev/null; then
    log_warn "claude não encontrado, pulando registro de MCP servers"
    return
  fi

  local existing
  existing=$(claude mcp list 2>/dev/null || true)

  local name
  for name in "${!CLAUDE_MCP_SERVERS[@]}"; do
    if grep -q "^${name}:" <<<"$existing"; then
      log_success "MCP server '$name' já registrado no Claude Code"
      continue
    fi
    if claude mcp add-json "$name" "${CLAUDE_MCP_SERVERS[$name]}" --scope user &>/dev/null; then
      log_success "MCP server '$name' registrado no Claude Code"
    else
      log_warn "Falha ao registrar MCP server '$name' no Claude Code"
    fi
  done
}

install_obsidian_rest_api_plugin() {
  local vault="$HOME/ObsidianVault"
  local plugin_dir="$vault/.obsidian/plugins/obsidian-local-rest-api"

  [[ -d "$vault/.obsidian" ]] || return

  if [[ -f "$plugin_dir/main.js" ]]; then
    log_success "Plugin 'obsidian-local-rest-api' já instalado no ObsidianVault"
    return
  fi

  if ! command -v curl &>/dev/null || ! command -v python3 &>/dev/null; then
    log_warn "curl/python3 não encontrados, pulando instalação do plugin Obsidian"
    return
  fi

  local base_url
  base_url=$(curl -s "https://api.github.com/repos/coddingtonbear/obsidian-local-rest-api/releases/latest" |
    grep -oP '"browser_download_url":\s*"\K[^"]+' | head -1 | xargs dirname)

  if [[ -z "$base_url" ]]; then
    log_warn "Não consegui consultar o release do plugin obsidian-local-rest-api, pulando"
    return
  fi

  mkdir -p "$plugin_dir"
  local asset ok=true
  for asset in main.js manifest.json styles.css; do
    if ! curl -sL -o "$plugin_dir/$asset" "$base_url/$asset"; then
      ok=false
    fi
  done

  if [[ "$ok" != true ]]; then
    log_warn "Falha ao baixar assets do plugin obsidian-local-rest-api"
    return
  fi

  python3 - "$vault/.obsidian/community-plugins.json" <<'PYEOF'
import json
import pathlib
import sys

p = pathlib.Path(sys.argv[1])
plugins = json.loads(p.read_text()) if p.exists() else []
if "obsidian-local-rest-api" not in plugins:
    plugins.append("obsidian-local-rest-api")
p.write_text(json.dumps(plugins, indent=2) + "\n")
PYEOF

  log_success "Plugin 'obsidian-local-rest-api' instalado. Abra o Obsidian, confirme 'Turn on community plugins' se pedido, ative o plugin em Settings > Community plugins, e copie a API key gerada para OBSIDIAN_API_KEY em ~/.bashrc.local"
}

log_info "Registrando MCP servers do Claude Code..."
register_claude_mcp_servers

echo ""
log_info "Verificando plugin Local REST API do Obsidian..."
install_obsidian_rest_api_plugin
