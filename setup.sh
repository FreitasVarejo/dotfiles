#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BACKUP_DIR="$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
HAS_BACKUP=false

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO] $1${NC}"; }
log_success() { echo -e "${GREEN}[OK] $1${NC}"; }
log_warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}"; }

declare -A STOW_TARGETS
STOW_TARGETS=(
    [bash]="$HOME"
    [conda]="$HOME"
    [tmux]="$HOME/.config/tmux"
    [nvim]="$HOME/.config/nvim"
    [git]="$HOME/.config/git"
    [yazi]="$HOME/.config/yazi"
    [opencode]="$HOME/.config/opencode"
)

# MCP servers to expose to Claude Code, mirroring opencode/opencode.json's
# enabled servers. Kept as a bash map (not a stowed file) because Claude Code
# stores user-scope MCP config inside ~/.claude.json, a stateful file (session
# history, project trust) that isn't safe to symlink wholesale.
# $GITHUB_TOKEN no valor de [github] abaixo é literal de propósito (aspas simples):
# headersHelper roda esse echo no momento da conexão, expandindo a variável no
# ambiente do Claude Code (vinda de ~/.bashrc.local), não no ambiente deste script.
declare -A CLAUDE_MCP_SERVERS
CLAUDE_MCP_SERVERS=(
    [git]='{"type":"stdio","command":"npx","args":["-y","git-mcp"]}'
    [docker]='{"type":"stdio","command":"npx","args":["-y","docker-mcp"]}'
    [github]='{"type": "http", "url": "https://api.githubcopilot.com/mcp/", "headersHelper": "echo \"{\\\"Authorization\\\": \\\"Bearer $GITHUB_TOKEN\\\"}\""}'
    [obsidian]='{"type":"stdio","command":"uvx","args":["mcp-obsidian"]}'
)
# 'sqlite' fica de fora: no opencode.json ele usa um path por-workspace
# (${workspaceFolder}/data/metadata.db), que não faz sentido como registro
# global de escopo 'user' no Claude Code.

if ! command -v stow &>/dev/null; then
    log_error "Stow is not installed."
    exit 1
fi

backup_path() {
    local target="$1"
    local label="${2:-backup}"

    if [[ -e "$target" || -h "$target" ]]; then
        # Resolve o path real independente de o symlink estar no próprio $target
        # ou em algum diretório pai (stow faz "tree folding": quando não há
        # conflito, ele symlinka um diretório inteiro, ex: ~/.config/nvim/lua ->
        # dotfiles/nvim/lua). Checar só "-h \"$target\"" ignora esse segundo caso
        # e trata arquivos que já vivem dentro do repo como conflito, apagando-os
        # do repo ao mover para o backup.
        local resolved
        resolved=$(readlink -f "$target" 2>/dev/null)
        if [[ -n "$resolved" && "$resolved" == "$SCRIPT_DIR"* ]]; then
            return
        fi

        if [[ "$HAS_BACKUP" == false ]]; then
            mkdir -p "$BACKUP_DIR"
            HAS_BACKUP=true
        fi

        log_warn "Conflict detected at $label. Moving to backup..."
        mkdir -p "$BACKUP_DIR/$(dirname "$target" | sed "s|^$HOME/||")"
        mv "$target" "$BACKUP_DIR/${target#$HOME/}"
    fi
}

backup_home_package() {
    local pkg_name="$1"
    local pkg_path="$SCRIPT_DIR/$pkg_name"

    for item in "$pkg_path"/* "$pkg_path"/.*; do
        [[ "$(basename "$item")" == "." ]] && continue
        [[ "$(basename "$item")" == ".." ]] && continue
        [[ "$(basename "$item")" == "*" ]] && continue

        [[ -e "$item" ]] || continue
        local rel_path
        rel_path=$(basename "$item")
        backup_path "$HOME/$rel_path" "~$rel_path"
    done
}

backup_xdg_package() {
    local pkg_name="$1"
    local local_target="${STOW_TARGETS[$pkg_name]}"
    local pkg_path="$SCRIPT_DIR/$pkg_name"

    while IFS= read -r -d '' file; do
        local rel_path="${file#$pkg_path/}"
        backup_path "$local_target/$rel_path" "$local_target/$rel_path"
    done < <(find "$pkg_path" -type f -print0 2>/dev/null | grep -vzE '\.md$')
}

register_claude_mcp_servers() {
    if ! command -v claude &>/dev/null; then
        log_warn "claude não encontrado, pulando registro de MCP servers"
        return
    fi

    local existing
    existing=$(claude mcp list 2>/dev/null || true)

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
    base_url=$(curl -s "https://api.github.com/repos/coddingtonbear/obsidian-local-rest-api/releases/latest" \
        | grep -oP '"browser_download_url":\s*"\K[^"]+' | head -1 | xargs dirname)

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

log_info "Starting dotfiles deployment..."

for pkg_name in "${!STOW_TARGETS[@]}"; do
    local_target="${STOW_TARGETS[$pkg_name]}"

    log_info "Processing package: $pkg_name -> $local_target"

    if [[ "$local_target" == "$HOME" ]]; then
        backup_home_package "$pkg_name"
    else
        backup_xdg_package "$pkg_name"
        mkdir -p "$local_target"
    fi

    if stow -R -t "$local_target" "$pkg_name" 2>/dev/null; then
        log_success "Stowed $pkg_name"
    elif stow -t "$local_target" "$pkg_name" 2>/dev/null; then
        log_success "Stowed $pkg_name"
    else
        log_warn "Failed to stow $pkg_name"
    fi
done

echo ""
log_info "Registrando MCP servers do Claude Code..."
register_claude_mcp_servers

echo ""
log_info "Verificando plugin Local REST API do Obsidian..."
install_obsidian_rest_api_plugin

echo ""
if [[ "$HAS_BACKUP" == true ]]; then
    log_success "Deployment complete with backups!"
    echo "Old files moved to: $BACKUP_DIR"
else
    log_success "Deployment complete (no conflicts)."
fi