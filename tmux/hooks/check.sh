#!/bin/bash
# shellcheck shell=bash
# Checks do pacote 'tmux': binário do tmux, Tmux Plugin Manager (TPM), os
# plugins e as unidades do snapshot. READ-ONLY.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"

TMUX_DIR="$HOME/.config/tmux"

log_info "--- Tmux ---"
check_cmd "tmux" "$PM_INSTALL tmux"
check_cmd "flock" "$PM_INSTALL util-linux (o snapshot usa para não gravar no meio de uma restauração)"

echo ""
log_info "--- Tmux Plugin Manager (TPM) ---"
if [ -x "$TMUX_DIR/plugins/tpm/tpm" ]; then
  log_success "TPM encontrado e executável: $TMUX_DIR/plugins/tpm/tpm"
else
  log_warn "TPM ausente ou sem executável em ~/.config/tmux/plugins/tpm/tpm."
  echo "    -> Executar: ~/dotfiles/setup.sh (clona o TPM e instala os plugins)"
  fail_check
fi

# Todo @plugin do tmux.conf precisa estar clonado; é o que o resurrect exige.
if [ -f "$DOTFILES_DIR/tmux/tmux.conf" ]; then
  while read -r plugin; do
    name="${plugin##*/}"
    if [ -f "$TMUX_DIR/plugins/$name/${name}.tmux" ] || [ -d "$TMUX_DIR/plugins/$name" ]; then
      log_success "Plugin do tmux presente: $name"
    else
      log_missing "Plugin do tmux ausente: $plugin"
      echo "    -> Executar: ~/dotfiles/setup.sh (o install_plugins do TPM clona)"
      fail_check
    fi
  done < <(sed -nE "s/^set -g @plugin '([^']+)'.*/\1/p" "$DOTFILES_DIR/tmux/tmux.conf" | grep -v '/tpm$')
fi

echo ""
log_info "--- Tmux: snapshot ---"
if [ -x "$TMUX_DIR/scripts/snapshot" ] && [ -x "$TMUX_DIR/scripts/revive" ]; then
  log_success "scripts/snapshot e scripts/revive stowados"
else
  log_missing "scripts/snapshot ou scripts/revive ausentes em $TMUX_DIR/scripts"
  echo "    -> Executar: ~/dotfiles/setup.sh"
  fail_check
fi

if command -v systemctl &>/dev/null && systemctl --user show-environment &>/dev/null; then
  if systemctl --user is-enabled tmux-snapshot.timer &>/dev/null; then
    log_success "tmux-snapshot.timer habilitado"
  else
    log_missing "tmux-snapshot.timer não habilitado"
    echo "    -> Ativar: ~/dotfiles/setup.sh (ou systemctl --user enable --now tmux-snapshot.timer)"
    fail_check
  fi

  if [ "$(loginctl show-user "$USER" -p Linger --value 2>/dev/null)" = "yes" ]; then
    if systemctl --user is-enabled tmux-server.service &>/dev/null; then
      log_success "tmux-server.service habilitado (linger ativo)"
    else
      log_missing "tmux-server.service não habilitado, e há linger: o tmux não sobe no boot"
      echo "    -> Ativar: ~/dotfiles/setup.sh (ou systemctl --user enable tmux-server.service)"
      fail_check
    fi
  else
    log_optional "Sem linger: o tmux não sobe no boot; o primeiro 't' restaura."
  fi
else
  log_optional "systemd de usuário indisponível; timer do snapshot não verificado."
fi

exit "$CHECK_FAILED"
