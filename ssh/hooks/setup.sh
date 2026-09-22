#!/bin/bash
# shellcheck shell=bash
# Setup do pacote 'ssh'. Cria o diretório dos sockets de multiplexação e
# semeia ~/.ssh/config.local (host-specific, NÃO versionado — o repo é público).

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"

SSH_DIR="$HOME/.ssh"
CM_DIR="$SSH_DIR/cm"
LOCAL_CONF="$SSH_DIR/config.local"

# O ssh recusa usar o diretório se ele for acessível a mais gente.
mkdir -p "$SSH_DIR" && chmod 700 "$SSH_DIR"

# ControlPath aponta para cá; sem o diretório a multiplexação falha em
# silêncio (cada conexão volta a pagar o handshake inteiro).
if mkdir -p "$CM_DIR" && chmod 700 "$CM_DIR"; then
  log_success "Diretório de multiplexação pronto: $CM_DIR"
else
  log_error "Não consegui criar $CM_DIR"
fi

# Semeia só se não existir: este arquivo é estado por máquina e nunca deve ser
# sobrescrito por um deploy.
if [[ ! -e "$LOCAL_CONF" ]]; then
  cat > "$LOCAL_CONF" <<'TEMPLATE'
# Hosts desta máquina. NÃO versionado (o repo dotfiles é público).
# Lido pelo `Include ~/.ssh/config.local` no topo de ~/.ssh/config.

# Host exemplo
#     HostName 10.0.0.1
#     User usuario
TEMPLATE
  chmod 600 "$LOCAL_CONF"
  log_success "Criado $LOCAL_CONF (template — ponha seus hosts aqui)"
else
  log_info "$LOCAL_CONF já existe, preservado."
fi
