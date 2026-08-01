#!/bin/bash
# shellcheck shell=bash
# Checks do pacote 'bash': shell base + ferramentas de sistema/CLI que o
# .bashrc e o fluxo de setup assumem no PATH, e o toolchain Node/NVM.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"

log_info "--- Ferramentas do Sistema ---"
check_cmd "git" "$PM_INSTALL git"
check_cmd "stow" "$PM_INSTALL stow"
check_cmd "curl" "$PM_INSTALL curl"
check_cmd "make" "$PM_INSTALL make (ou build-essential/@development-tools)"
check_cmd "gcc" "$PM_INSTALL gcc (ou build-essential/@development-tools)"

echo ""
log_info "--- Ferramentas CLI ---"
check_cmd "rg" "$PM_INSTALL ripgrep"

# fd com checagem de versão (Snacks picker exige >= 8.4 para novas sintaxes).
if command -v fd &>/dev/null; then
  FD_VER=$(fd --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
  if [ -n "$FD_VER" ]; then
    FD_MAJOR=$(echo "$FD_VER" | cut -d. -f1)
    FD_MINOR=$(echo "$FD_VER" | cut -d. -f2)
    if [ "$FD_MAJOR" -lt 8 ] || { [ "$FD_MAJOR" -eq 8 ] && [ "$FD_MINOR" -lt 4 ]; }; then
      log_warn "fd encontrado ($FD_VER) mas versão < 8.4 — Snacks picker pode falhar."
      echo "    -> Atualizar fd: $PM_INSTALL fd-find ou compile from source."
    else
      log_success "fd encontrado: $FD_VER ($(command -v fd))"
    fi
  else
    log_success "fd encontrado: $(command -v fd)"
  fi
else
  check_cmd "fd" "$PM_INSTALL fd-find (depois linkar fdfind -> fd)" "no" "fdfind"
fi

check_cmd "bat" "$PM_INSTALL bat (depois linkar batcat -> bat)" "no" "batcat"
check_cmd "fzf" "git clone --depth 1 https://github.com/junegunn/fzf.git ~/.config/fzf && ~/.config/fzf/install"
check_cmd "zoxide" "curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash"
check_cmd "starship" "curl -sS https://starship.rs/install.sh | sh"

echo ""
log_info "--- Node.js / NVM ---"
if [ -d "$HOME/.nvm" ]; then
  if command -v node &>/dev/null; then
    NODE_VER=$(node --version)
    log_success "Node.js encontrado: $NODE_VER via NVM"
  else
    log_warn "NVM instalado mas Node.js não encontrado."
    echo "    -> Execute: nvm use default (o lazy-load no .bashrc carrega o nvm na primeira chamada)"
  fi
else
  log_warn "NVM não encontrado."
  echo "    -> Instalar: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
fi

exit "$CHECK_FAILED"
