#!/bin/bash
# shellcheck shell=bash
# Checks do pacote 'opencode': binário do opencode, Claude Code + MCP servers
# registrados, uvx, secrets (tokens) e o plugin Local REST API do Obsidian.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"
# shellcheck source=./mcp-servers.sh
. "$(dirname "${BASH_SOURCE[0]}")/mcp-servers.sh"

log_info "--- OpenCode ---"
if command -v opencode &>/dev/null; then
  OC_VER=$(opencode --version 2>&1 | head -n1)
  log_success "OpenCode encontrado: $OC_VER ($(command -v opencode))"
else
  log_warn "OpenCode não encontrado (config em ~/.config/opencode não será usada)."
  echo "    -> Instalar: curl -fsSL https://opencode.ai/install | bash"
fi

echo ""
log_info "--- Claude Code + MCP servers ---"
if command -v claude &>/dev/null; then
  CC_VER=$(claude --version 2>&1 | head -n1)
  log_success "Claude Code encontrado: $CC_VER ($(command -v claude))"
  CC_MCP_LIST=$(claude mcp list 2>/dev/null)
  for mcp_name in "${!CLAUDE_MCP_SERVERS[@]}"; do
    if grep -q "^${mcp_name}:" <<<"$CC_MCP_LIST"; then
      log_success "MCP server '$mcp_name' registrado (user scope)"
    else
      log_warn "MCP server '$mcp_name' não registrado. Execute ./setup.sh para registrar."
    fi
  done
else
  log_warn "Claude Code não encontrado (registro de MCP servers em setup.sh será pulado)."
  echo "    -> Instalar: https://docs.claude.com/en/docs/claude-code"
fi

echo ""
log_info "--- Dependências de MCP (uvx / secrets) ---"
if command -v uvx &>/dev/null; then
  log_success "uvx encontrado ($(command -v uvx)) - necessário para o MCP server 'obsidian'"
else
  log_warn "uvx não encontrado (MCP server 'obsidian' vai falhar ao conectar)."
  echo "    -> Instalar: $PM_INSTALL uv"
fi

if [ -n "$GITHUB_TOKEN" ]; then
  log_success "GITHUB_TOKEN definido (MCP server 'github' pronto para autenticar)"
else
  log_warn "GITHUB_TOKEN não definido. Adicione em ~/.bashrc.local (não rastreado pelo git)."
fi

if [ -n "$OBSIDIAN_API_KEY" ]; then
  log_success "OBSIDIAN_API_KEY definido (MCP server 'obsidian' pronto para autenticar)"
else
  log_warn "OBSIDIAN_API_KEY não definido. Adicione em ~/.bashrc.local (não rastreado pelo git)."
fi

if [ -f "$HOME/ObsidianVault/.obsidian/plugins/obsidian-local-rest-api/main.js" ]; then
  log_success "Plugin 'obsidian-local-rest-api' instalado no ObsidianVault"
else
  log_warn "Plugin 'obsidian-local-rest-api' não encontrado no ObsidianVault."
  echo "    -> Execute ./setup.sh para instalar, depois abra o Obsidian para ativá-lo."
fi

# A REST API roda dentro do app do Obsidian: sem o app aberto, as tools do MCP
# server 'obsidian' falham mesmo com tudo instalado e o server "conectado".
if curl -sk --max-time 3 -o /dev/null "https://127.0.0.1:27124/"; then
  log_success "Local REST API respondendo em 127.0.0.1:27124 (Obsidian aberto)"
else
  log_warn "Nada respondendo em 127.0.0.1:27124 - as tools do MCP 'obsidian' vão falhar."
  echo "    -> Abra o app do Obsidian (a REST API é um plugin dele, não um serviço)."
fi

exit "$CHECK_FAILED"
