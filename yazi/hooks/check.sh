#!/bin/bash
# shellcheck shell=bash
# Checks do pacote 'yazi': binário do yazi + flavor catppuccin-mocha instalado.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"

log_info "--- Yazi ---"
check_cmd "yazi" "curl -sS https://yazi-rs.github.io/install.sh | bash (ou via $PM_INSTALL yazi)"

echo ""
log_info "--- Yazi Flavor ---"
if [ -d "$HOME/.config/yazi/flavors/catppuccin-mocha.yazi" ]; then
  log_success "Flavor catppuccin-mocha instalado"
else
  log_warn "Flavor catppuccin-mocha não encontrado."
  echo "    -> Execute: cd ~/dotfiles/yazi && ya pkg install"
fi

exit "$CHECK_FAILED"
