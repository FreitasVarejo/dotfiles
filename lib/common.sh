#!/bin/bash
# shellcheck shell=bash
#
# Biblioteca compartilhada pelos scripts de setup/healthcheck e pelos hooks
# por pacote (<pkg>/hooks/check.sh, <pkg>/hooks/setup.sh).
#
# Uso:
#   DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
#   . "$DOTFILES_DIR/lib/common.sh"
#
# Convenções de hook:
#   - check.sh é READ-ONLY. Marca falhas com fail_check e termina com
#     `exit $CHECK_FAILED` (0 = tudo ok/obrigatórios presentes).
#   - setup.sh pode mutar estado (rodar após o stow do pacote).

# Evita re-sourcing (funções/vars redefinidas à toa).
[[ -n "${_DOTFILES_COMMON_SH:-}" ]] && return
_DOTFILES_COMMON_SH=1

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO] $1${NC}"; }
log_success() { echo -e "${GREEN}[OK] $1${NC}"; }
log_warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
log_missing() { echo -e "${YELLOW}[MISSING] $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}"; }
log_optional() { echo -e "${BLUE}[OPTIONAL] $1${NC}"; }

# Detecta o gerenciador de pacotes do sistema e expõe PM_INSTALL como prefixo
# de instalação (ex.: "sudo dnf install"). Substitui as dicas hardcoded de apt.
detect_pkg_manager() {
  [[ -n "${PM_INSTALL:-}" ]] && return
  if command -v dnf &>/dev/null; then
    PM_INSTALL="sudo dnf install"
  elif command -v apt &>/dev/null; then
    PM_INSTALL="sudo apt install"
  elif command -v pacman &>/dev/null; then
    PM_INSTALL="sudo pacman -S"
  elif command -v brew &>/dev/null; then
    PM_INSTALL="brew install"
  elif command -v zypper &>/dev/null; then
    PM_INSTALL="sudo zypper install"
  else
    PM_INSTALL="<gerenciador de pacotes> install"
  fi
}
detect_pkg_manager

# Flag agregada de falha para hooks de check. Cada check.sh termina com
# `exit $CHECK_FAILED`. fail_check() marca que um obrigatório está faltando.
CHECK_FAILED=0
# shellcheck disable=SC2034  # CHECK_FAILED é lida pelos hooks via `exit $CHECK_FAILED`
fail_check() { CHECK_FAILED=1; }

# check_cmd <name> [install_hint] [optional] [alt...]
#   - install_hint: texto de sugestão (pode conter $PM_INSTALL já expandido).
#   - optional: "optional" torna a ausência não-fatal (não marca CHECK_FAILED).
#   - alt...: nomes alternativos do binário (ex.: fdfind para fd).
check_cmd() {
  local cmd_name=$1
  local install_hint=${2:-}
  local optional=${3:-no}
  # Consome os 3 primeiros args (ou menos, se não vieram) e deixa o resto como alternativas.
  local consumed=$(($# < 3 ? $# : 3))
  shift "$consumed"
  local alternatives=("$@")

  if command -v "$cmd_name" &>/dev/null; then
    log_success "$cmd_name encontrado: $(command -v "$cmd_name")"
    return 0
  fi

  if [[ "$optional" == "optional" ]]; then
    log_optional "$cmd_name não encontrado (opcional)."
  else
    log_missing "$cmd_name não encontrado."
  fi

  local alt
  for alt in "${alternatives[@]}"; do
    if command -v "$alt" &>/dev/null; then
      log_info "  -> Nota: instalado como '$alt' (considere um alias ou symlink)."
    fi
  done

  if [[ -n "$install_hint" ]]; then
    echo "    -> Sugestão: $install_hint"
  fi

  [[ "$optional" != "optional" ]] && fail_check
  return 1
}
