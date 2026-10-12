#!/bin/bash
# shellcheck shell=bash
# Setup do pacote 'cloudflare': instala a CLI `cf` na versão fixa de lib.sh,
# num prefixo privado que o wrapper .local/bin/cf usa. Idempotente: só chama o
# npm quando a versão instalada é outra.
#
# Os tokens não passam por aqui. Cada máquina grava os seus à mão (o check.sh
# mostra o comando), para que nenhum segredo atravesse o repo nem o agente.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log_info "--- Cloudflare (cf) ---"

if ! command -v npm &>/dev/null; then
  log_warn "npm não encontrado; cf não instalado"
  echo "    -> $PM_INSTALL nodejs npm && ~/dotfiles/setup.sh"
  exit 0
fi

if ! node_at_least "$CF_NODE_MIN"; then
  log_warn "cf pede Node >= $CF_NODE_MIN (no PATH: $(node --version 2>/dev/null || echo nenhum)); cf não instalado"
  exit 0
fi

HAVE=$(cf_installed_version)
if [[ "$HAVE" == "$CF_VERSION" && -x "$CF_BIN" ]]; then
  log_success "cf $CF_VERSION em dia: ${CF_PREFIX/#$HOME/\~}"
elif npm install --prefix "$CF_PREFIX" --save-exact --no-audit --no-fund --loglevel=error \
  "cf@$CF_VERSION" >/dev/null; then
  log_success "cf $CF_VERSION instalado em ${CF_PREFIX/#$HOME/\~}${HAVE:+ (era $HAVE)}"
else
  log_warn "npm install do cf falhou"
  echo "    -> Rode à mão para ver o erro: npm install --prefix \"$CF_PREFIX\" cf@$CF_VERSION"
fi
