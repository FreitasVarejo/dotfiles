#!/bin/bash
# shellcheck shell=bash
# Checks do pacote 'tmux': binário do tmux + Tmux Plugin Manager (TPM).

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"

log_info "--- Tmux ---"
check_cmd "tmux" "$PM_INSTALL tmux"

echo ""
log_info "--- Tmux Plugin Manager (TPM) ---"
if [ -x "$HOME/.config/tmux/plugins/tpm/tpm" ]; then
  log_success "TPM encontrado e executável: $HOME/.config/tmux/plugins/tpm/tpm"
else
  log_warn "TPM ausente ou sem executável em ~/.config/tmux/plugins/tpm/tpm."
  echo "    -> Executar: git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm"
  fail_check
fi

exit "$CHECK_FAILED"
