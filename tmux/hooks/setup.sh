#!/bin/bash
# shellcheck shell=bash
# Setup do pacote 'tmux': TPM e os plugins, e as unidades systemd de usuário do
# snapshot (restauração depois de uma queda).
#
#   - TPM: clone em ~/.config/tmux/plugins/tpm, se falta; depois instala os
#     plugins declarados no tmux.conf (tmux-resurrect entre eles)
#   - tmux-snapshot.timer: grava o snapshot a cada 5 min
#   - tmux-server.service: sobe o tmux no boot e restaura; só onde há linger
#     (sem linger o serviço só subiria no login, e aí o primeiro `t` já restaura)
#
# Idempotente.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"

TMUX_DIR="$HOME/.config/tmux"
TPM_DIR="$TMUX_DIR/plugins/tpm"
UNITS_SRC="$DOTFILES_DIR/tmux/hooks/systemd"
UNITS_DEST="$HOME/.config/systemd/user"

log_info "--- Tmux: TPM e plugins ---"
if [[ -x "$TPM_DIR/tpm" ]]; then
  log_success "TPM já instalado: $TPM_DIR"
elif command -v git &>/dev/null; then
  mkdir -p "$TMUX_DIR/plugins"
  if git clone --quiet --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"; then
    log_success "TPM clonado em $TPM_DIR"
  else
    log_warn "Falha ao clonar o TPM"
  fi
else
  log_warn "git não encontrado; TPM não instalado"
fi

if [[ -x "$TPM_DIR/bin/install_plugins" ]]; then
  # O install_plugins lê os @plugin do tmux.conf e só clona o que falta.
  if TMUX_PLUGIN_MANAGER_PATH="$TMUX_DIR/plugins/" "$TPM_DIR/bin/install_plugins" >/dev/null 2>&1; then
    log_success "Plugins do tmux em dia"
  else
    log_warn "install_plugins do TPM falhou"
    echo "    -> Rode à mão para ver o erro: TMUX_PLUGIN_MANAGER_PATH=$TMUX_DIR/plugins/ $TPM_DIR/bin/install_plugins"
  fi
fi

echo ""
log_info "--- Tmux: snapshot (systemd de usuário) ---"
if ! command -v systemctl &>/dev/null || ! systemctl --user show-environment &>/dev/null; then
  log_warn "systemd de usuário indisponível; ative tmux-snapshot.timer à mão depois."
  exit 0
fi

mkdir -p "$UNITS_DEST"
for unit in tmux-snapshot.service tmux-snapshot.timer tmux-server.service; do
  ln -sfn "$UNITS_SRC/$unit" "$UNITS_DEST/$unit"
done
systemctl --user daemon-reload

if systemctl --user enable --now tmux-snapshot.timer &>/dev/null; then
  log_success "tmux-snapshot.timer ativo (a cada 5 min)"
else
  log_warn "Não consegui ativar tmux-snapshot.timer"
fi

if [[ "$(loginctl show-user "$USER" -p Linger --value 2>/dev/null)" == "yes" ]]; then
  # Só `enable`: o serviço roda no próximo boot. Subir agora criaria uma sessão 0
  # num servidor que já está de pé.
  if systemctl --user enable tmux-server.service &>/dev/null; then
    log_success "tmux-server.service habilitado (linger ativo: o tmux sobe no boot)"
  else
    log_warn "Não consegui habilitar tmux-server.service"
  fi
else
  log_optional "Sem linger: o tmux não sobe no boot; o primeiro 't' restaura."
fi
