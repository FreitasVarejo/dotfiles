#!/bin/bash
# shellcheck shell=bash
# Check do pacote 'git': identidade global configurada. READ-ONLY — se faltar,
# apenas avisa (a configuração interativa vive em git/hooks/setup.sh).

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"

log_info "--- Git Identity ---"
git_name=$(git config --global user.name 2>/dev/null)
git_email=$(git config --global user.email 2>/dev/null)

if [ -n "$git_name" ] && [ -n "$git_email" ]; then
  log_success "Git identity configurada: $git_name <$git_email>"
else
  log_warn "Git identity não configurada (user.name / user.email ausentes)."
  echo "    -> Execute ./setup.sh (git/hooks/setup.sh pergunta e configura)."
fi

exit "$CHECK_FAILED"
