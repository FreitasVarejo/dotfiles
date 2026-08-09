#!/bin/bash
# shellcheck shell=bash
# Setup do pacote 'vault': cria o repositório de checkpoints do vault do
# Obsidian (fora da pasta sincronizada) e ativa o timer que o alimenta.
#
# Idempotente: repetir não recria o repo nem duplica o exclude.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"

VAULT_GIT_DIR="$HOME/.local/state/obsidian-vault.git"
VAULT_WORK_TREE="$HOME/ObsidianVault"

log_info "--- Vault (checkpoints git) ---"

if [[ ! -d "$VAULT_WORK_TREE" ]]; then
  log_warn "Vault não encontrado em $VAULT_WORK_TREE; pulando."
  exit 0
fi

# 1. Repositório, com metadata FORA do vault ---------------------------------
# `--bare` + core.bare=false + core.worktree é o que permite o .git morar em
# outro lugar sem deixar nenhum arquivo de git dentro da pasta sincronizada
# (um `.git` de verdade, ou mesmo o arquivo-ponteiro do --separate-git-dir,
# seria replicado pelo Syncthing e corromperia o repo entre dispositivos).
if [[ -d "$VAULT_GIT_DIR" ]]; then
  log_success "Repo de checkpoints já existe: $VAULT_GIT_DIR"
else
  mkdir -p "$(dirname "$VAULT_GIT_DIR")"
  git init --bare --quiet "$VAULT_GIT_DIR"
  git --git-dir="$VAULT_GIT_DIR" config core.bare false
  git --git-dir="$VAULT_GIT_DIR" config core.worktree "$VAULT_WORK_TREE"
  # Ruído puro num repo de snapshots: o vault inteiro é reescrito a cada
  # checkpoint se o git achar que precisa normalizar finais de linha.
  git --git-dir="$VAULT_GIT_DIR" config core.autocrlf false
  log_success "Repo de checkpoints criado: $VAULT_GIT_DIR"
fi

# 2. Exclusões ---------------------------------------------------------------
# Em $GIT_DIR/info/exclude e NÃO num .gitignore: um .gitignore dentro do vault
# seria sincronizado para os outros dispositivos, poluindo uma pasta que não
# tem nada a ver com git.
EXCLUDE_FILE="$VAULT_GIT_DIR/info/exclude"
mkdir -p "$(dirname "$EXCLUDE_FILE")"
cat >"$EXCLUDE_FILE" <<'EOF'
# Gerado por dotfiles/vault/hooks/setup.sh — edições serão sobrescritas.

# Metadata do próprio Syncthing
/.stfolder/
/.stversions/
/.stignore
/.mcp-ssh.lock

# Estado de UI do Obsidian: muda a cada painel movido, geraria checkpoint sem
# nenhum conteúdo real.
/.obsidian/workspace.json
/.obsidian/workspace-mobile.json
EOF
log_success "Exclusões gravadas em info/exclude"

# 3. Commit inicial ----------------------------------------------------------
if git --git-dir="$VAULT_GIT_DIR" --work-tree="$VAULT_WORK_TREE" \
  rev-parse --verify HEAD &>/dev/null; then
  log_success "Histórico já iniciado ($(git --git-dir="$VAULT_GIT_DIR" rev-list --count HEAD) checkpoints)"
else
  git --git-dir="$VAULT_GIT_DIR" --work-tree="$VAULT_WORK_TREE" add -A
  git --git-dir="$VAULT_GIT_DIR" --work-tree="$VAULT_WORK_TREE" \
    commit -q -m "checkpoint inicial do vault"
  log_success "Commit inicial criado"
fi

# 4. Timer -------------------------------------------------------------------
if command -v systemctl &>/dev/null && systemctl --user show-environment &>/dev/null; then
  systemctl --user daemon-reload
  if systemctl --user enable --now vault-checkpoint.timer &>/dev/null; then
    log_success "Timer vault-checkpoint.timer ativo (a cada 15 min)"
  else
    log_warn "Não consegui ativar vault-checkpoint.timer"
  fi
else
  log_warn "systemd de usuário indisponível; ative o timer à mão depois."
fi
