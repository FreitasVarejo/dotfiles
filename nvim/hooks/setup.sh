#!/bin/bash
# shellcheck shell=bash
# Setup do pacote 'nvim': clona o freitask.nvim se ainda não existir.
#
# check.sh só lê e avisa (read-only); clonar é mutação de estado, então mora
# aqui. Idempotente: se o clone já existe, não mexe nele — quem controla
# quando dar `git pull` é o usuário, não este script (mesmo motivo do spec do
# lazy.nvim usar `dir=` em vez de URL).

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"

FREITASK_REPO="${FREITASK_REPO:-$HOME/dev/freitask.nvim}"
FREITASK_REMOTE="git@github.com:FreitasVarejo/freitask.nvim.git"

log_info "--- Freitask (plugin externo) ---"

if [[ -f "$FREITASK_REPO/lua/freitask/init.lua" ]]; then
  log_success "freitask.nvim já clonado: $FREITASK_REPO"
elif command -v git &>/dev/null; then
  mkdir -p "$(dirname "$FREITASK_REPO")"
  if git clone --quiet "$FREITASK_REMOTE" "$FREITASK_REPO"; then
    log_success "freitask.nvim clonado em $FREITASK_REPO"
  else
    log_warn "Falha ao clonar freitask.nvim de $FREITASK_REMOTE"
  fi
else
  log_warn "git não encontrado; não foi possível clonar freitask.nvim"
fi
