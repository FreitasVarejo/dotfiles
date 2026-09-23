#!/bin/bash
# shellcheck shell=bash
#
# Portão de pré-commit. A lista de arquivos é DERIVADA do git (versionados +
# novos não ignorados), nunca de glob: glob esquece arquivo em silêncio — foi
# assim que `*/hooks/*.sh` deixou os binários do vault de fora e
# `plugins/**/*.lua` (sem globstar) deixou de fora quase todo o nvim.
#
#   shell  shebang bash/sh ou extensão .sh  -> shellcheck -x -P SCRIPTDIR
#   lua    *.lua                            -> luac -p
#   tmux   tmux/tmux.conf                   -> source-file -n num socket privado
#   nvim   config real                      -> nvim --headless +checkhealth
#
# Ferramenta ausente é aviso, não falha: o portão não depende de quem
# instalou o quê.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"

usage() {
  cat <<EOF
Uso: ./precommit.sh [--list]

  (sem opção)  roda todas as etapas; sai != 0 se alguma falhar
  --list       mostra o que cada etapa cobre e sai 0
EOF
}

LIST_ONLY=false
case "${1:-}" in
  "") ;;
  --list) LIST_ONLY=true ;;
  -h | --help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

cd "$DOTFILES_DIR" || exit 1

SHELL_FILES=()
LUA_FILES=()
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  if [[ "$f" == *.lua ]]; then
    LUA_FILES+=("$f")
  elif [[ "$f" == *.sh ]] || head -n1 "$f" 2>/dev/null | grep -qE '^#!.*[/ ](ba)?sh\b'; then
    SHELL_FILES+=("$f")
  fi
done < <(git ls-files --cached --others --exclude-standard | sort -u)

TMUX_CONF="tmux/tmux.conf"

if [[ "$LIST_ONLY" == true ]]; then
  echo "## shell (${#SHELL_FILES[@]})"
  printf '  %s\n' "${SHELL_FILES[@]}"
  echo "## lua (${#LUA_FILES[@]})"
  printf '  %s\n' "${LUA_FILES[@]}"
  echo "## tmux"
  echo "  $TMUX_CONF"
  echo "## nvim"
  echo "  config carregada de ~/.config/nvim (checkhealth)"
  exit 0
fi

# have <cmd> <etapa>: avisa e devolve 1 se a ferramenta faltar.
have() {
  command -v "$1" &>/dev/null && return 0
  log_warn "$1 não encontrado: etapa '$2' pulada. Sugestão: $PM_INSTALL $1"
  return 1
}

if have shellcheck shell; then
  if shellcheck -x -P SCRIPTDIR "${SHELL_FILES[@]}"; then
    log_success "shellcheck: ${#SHELL_FILES[@]} arquivos"
  else
    log_error "shellcheck falhou"
    fail_check
  fi
fi

if have luac lua; then
  if luac -p "${LUA_FILES[@]}"; then
    log_success "luac: ${#LUA_FILES[@]} arquivos"
  else
    log_error "luac falhou"
    fail_check
  fi
fi

if have tmux tmux; then
  # Socket privado e -n (só parse): não toca no servidor do usuário.
  # O tmux imprime o erro de parse e mesmo assim sai 0 — o sinal é a saída.
  TMUX_OUT=$(command tmux -L "precommit-$$" -f /dev/null start-server \; \
    source-file -n "$TMUX_CONF" \; kill-server 2>&1)
  TMUX_RC=$?
  # kill-server não apaga o socket; sem isto, cada rodada deixa um arquivo.
  rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/precommit-$$"
  if [[ $TMUX_RC -eq 0 && -z "$TMUX_OUT" ]]; then
    log_success "tmux: $TMUX_CONF"
  else
    echo "$TMUX_OUT"
    log_error "tmux: $TMUX_CONF não parseia"
    fail_check
  fi
fi

if have nvim nvim; then
  NVIM_OUT=$(nvim --headless "+checkhealth" +qa 2>&1)
  if [[ $? -eq 0 && "$NVIM_OUT" != *"Error"* ]]; then
    log_success "nvim: config carrega"
  else
    echo "$NVIM_OUT"
    log_error "nvim: erro ao carregar a config"
    fail_check
  fi
fi

exit "$CHECK_FAILED"
