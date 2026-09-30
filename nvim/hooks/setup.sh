#!/bin/bash
# shellcheck shell=bash
# Setup do pacote 'nvim': aquece o lazy.nvim (instala plugin que falta).
#
# O clone do freitask morava aqui enquanto o Neovim o carregava como plugin;
# desde que o picker virou a TUI, quem precisa do clone é a CLI, e ele mora no
# hook do pacote 'vault'.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"

log_info "--- Neovim warmup (lazy.nvim) ---"
# Estava no check.sh, que precisa ser read-only. `install` e não `sync`: só
# baixa o que falta e não reescreve o lazy-lock.json do repo.
if command -v nvim &>/dev/null; then
  if timeout 300 nvim --headless "+Lazy! install" +qa &>/dev/null; then
    log_success "Plugins do lazy.nvim instalados"
  else
    log_warn "Warmup do lazy.nvim falhou ou excedeu 300s"
    echo "    -> Rode à mão para ver o erro: nvim --headless '+Lazy! install' +qa"
  fi
else
  log_info "Warmup pulado (nvim ausente)."
fi
