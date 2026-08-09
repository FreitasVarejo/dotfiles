#!/bin/bash
# shellcheck shell=bash
# Checks READ-ONLY do pacote 'vault': repositório de checkpoints, timer e
# integridade dos dados do freitask (via `freitask doctor`).

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"

VAULT_GIT_DIR="$HOME/.local/state/obsidian-vault.git"
VAULT_WORK_TREE="$HOME/ObsidianVault"

log_info "--- Vault do Obsidian ---"

if [[ ! -d "$VAULT_WORK_TREE" ]]; then
  log_optional "Vault não encontrado em $VAULT_WORK_TREE (nada a checar)."
  exit "${CHECK_FAILED:-0}"
fi

# 1. Repo de checkpoints -----------------------------------------------------
if [[ -d "$VAULT_GIT_DIR" ]]; then
  n=$(git --git-dir="$VAULT_GIT_DIR" rev-list --count HEAD 2>/dev/null || echo 0)
  log_success "Repo de checkpoints: $n commit(s)"

  # Um repo que parou de receber checkpoints é pior que não ter repo: dá
  # sensação de rede de proteção sem existir.
  last=$(git --git-dir="$VAULT_GIT_DIR" log -1 --format=%ct 2>/dev/null || echo 0)
  if [[ "$last" != "0" ]]; then
    age=$((($(date +%s) - last) / 3600))
    if ((age > 48)); then
      log_warn "Último checkpoint há ${age}h — o timer está rodando?"
    else
      log_success "Último checkpoint há ${age}h"
    fi
  fi
else
  log_missing "Repo de checkpoints ausente ($VAULT_GIT_DIR)"
  echo "    -> Criar: ~/dotfiles/setup.sh"
  fail_check
fi

# 2. Timer -------------------------------------------------------------------
if command -v systemctl &>/dev/null && systemctl --user show-environment &>/dev/null; then
  if systemctl --user is-enabled vault-checkpoint.timer &>/dev/null; then
    log_success "vault-checkpoint.timer habilitado"
  else
    log_missing "vault-checkpoint.timer não habilitado"
    echo "    -> Ativar: systemctl --user enable --now vault-checkpoint.timer"
    fail_check
  fi
else
  log_optional "systemd de usuário indisponível; timer não verificado."
fi

# 3. Versionamento do Syncthing ----------------------------------------------
# Não é obrigatório (o repo de checkpoints já cobre undo), mas vale saber que
# não existe: sem os dois, um arquivo sobrescrito pelo celular some sem rastro
# até o próximo checkpoint.
ST_CONFIG="$HOME/.local/state/syncthing/config.xml"
[[ -f "$ST_CONFIG" ]] || ST_CONFIG="$HOME/.config/syncthing/config.xml"
if [[ -f "$ST_CONFIG" ]] && ! grep -q '<versioning>[^<]*<type>' "$ST_CONFIG" 2>/dev/null; then
  log_optional "Syncthing sem versionamento na pasta do vault (undo depende só dos checkpoints)."
fi

# 4. Integridade dos dados do freitask ---------------------------------------
if command -v freitask &>/dev/null; then
  if freitask doctor --quiet; then
    log_success "freitask doctor: vault consistente"
  else
    log_warn "freitask doctor encontrou inconsistências"
    echo "    -> Detalhes: freitask doctor"
    echo "    -> Reparar o que for automático: freitask doctor --fix"
  fi
else
  log_missing "CLI 'freitask' não encontrada no PATH"
  echo "    -> Aplicar os dotfiles: ~/dotfiles/setup.sh"
  fail_check
fi

exit "${CHECK_FAILED:-0}"
