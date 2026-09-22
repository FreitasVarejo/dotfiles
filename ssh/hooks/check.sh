#!/bin/bash
# shellcheck shell=bash
# Check do pacote 'ssh': multiplexação utilizável e hosts locais presentes.
# READ-ONLY — o que cria diretório/template vive em ssh/hooks/setup.sh.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"

log_info "--- SSH ---"
check_cmd ssh "$PM_INSTALL openssh-clients"

CM_DIR="$HOME/.ssh/cm"
LOCAL_CONF="$HOME/.ssh/config.local"

# Sem o diretório o ControlPath não resolve e a multiplexação some sem erro
# visível: tudo continua funcionando, só que lento de novo.
if [[ -d "$CM_DIR" ]]; then
  perms=$(stat -c '%a' "$CM_DIR" 2>/dev/null)
  if [[ "$perms" == "700" ]]; then
    log_success "Multiplexação: $CM_DIR (700)"
  else
    log_warn "$CM_DIR tem permissão $perms (esperado 700)."
    echo "    -> Execute ./setup.sh para corrigir."
  fi
else
  log_missing "$CM_DIR não existe — multiplexação inativa."
  echo "    -> Execute ./setup.sh (ssh/hooks/setup.sh cria o diretório)."
  fail_check
fi

# O Include no topo do config é incondicional: se o arquivo sumir, o ssh
# reclama em toda conexão.
if [[ -f "$LOCAL_CONF" ]]; then
  log_success "Hosts locais: $LOCAL_CONF"
else
  log_missing "$LOCAL_CONF não existe (o config versionado faz Include dele)."
  echo "    -> Execute ./setup.sh para semear o template."
  fail_check
fi

# Guarda de vazamento: o config versionado não pode ganhar host/IP, porque
# FreitasVarejo/dotfiles é público.
REPO_CONF="$DOTFILES_DIR/ssh/.ssh/config"
if grep -qiE '^[[:space:]]*(HostName|User)[[:space:]]' "$REPO_CONF" 2>/dev/null; then
  log_warn "$REPO_CONF tem HostName/User — isso vai para um repo PÚBLICO."
  echo "    -> Mova esses blocos para ~/.ssh/config.local."
  fail_check
else
  log_success "Config versionado sem host/IP"
fi

exit "$CHECK_FAILED"
