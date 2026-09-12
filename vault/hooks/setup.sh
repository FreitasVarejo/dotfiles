#!/bin/bash
# shellcheck shell=bash
# Setup do pacote 'vault': cria os repositórios de checkpoints dos vaults do
# Obsidian (fora das pastas sincronizadas) e ativa os timers que os alimentam.
#
#   - vault pessoal (~/ObsidianVault)            -> vault-checkpoint.timer
#   - vaults extras (~/.config/vault-checkpoint/<nome>.env, stowados deste
#     pacote)                                     -> vault-checkpoint@<nome>.timer
#
# Idempotente: repetir não recria repo, não duplica exclude nem remoto.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"

# ensure_vault_repo <git_dir> <work_tree>   (conteúdo do info/exclude via stdin)
#
# `--bare` + core.bare=false + core.worktree é o que permite o .git morar em
# outro lugar sem deixar nenhum arquivo de git dentro da pasta sincronizada
# (um `.git` de verdade, ou mesmo o arquivo-ponteiro do --separate-git-dir,
# seria replicado pelo Syncthing e corromperia o repo entre dispositivos).
# O exclude vai em $GIT_DIR/info/exclude e NÃO num .gitignore: um .gitignore
# dentro do vault seria sincronizado para os outros dispositivos.
ensure_vault_repo() {
  local git_dir="$1" work_tree="$2"

  if [[ -d "$git_dir" ]]; then
    log_success "Repo de checkpoints já existe: $git_dir"
  else
    mkdir -p "$(dirname "$git_dir")"
    git init --bare --quiet -b main "$git_dir"
    git --git-dir="$git_dir" config core.bare false
    git --git-dir="$git_dir" config core.worktree "$work_tree"
    # Ruído puro num repo de snapshots: o vault inteiro é reescrito a cada
    # checkpoint se o git achar que precisa normalizar finais de linha.
    git --git-dir="$git_dir" config core.autocrlf false
    log_success "Repo de checkpoints criado: $git_dir"
  fi

  mkdir -p "$git_dir/info"
  cat >"$git_dir/info/exclude"
  log_success "Exclusões gravadas em info/exclude"

  if git --git-dir="$git_dir" --work-tree="$work_tree" rev-parse --verify HEAD &>/dev/null; then
    log_success "Histórico já iniciado ($(git --git-dir="$git_dir" rev-list --count HEAD) checkpoints)"
  else
    git --git-dir="$git_dir" --work-tree="$work_tree" add -A
    git --git-dir="$git_dir" --work-tree="$work_tree" commit -q -m "checkpoint inicial do vault"
    log_success "Commit inicial criado"
  fi
}

enable_timer() {
  local unit="$1"
  if command -v systemctl &>/dev/null && systemctl --user show-environment &>/dev/null; then
    systemctl --user daemon-reload
    if systemctl --user enable --now "$unit" &>/dev/null; then
      log_success "Timer $unit ativo (a cada 15 min)"
    else
      log_warn "Não consegui ativar $unit"
    fi
  else
    log_warn "systemd de usuário indisponível; ative $unit à mão depois."
  fi
}

# 1. Vault pessoal -----------------------------------------------------------
log_info "--- Vault (checkpoints git) ---"
if [[ -d "$HOME/ObsidianVault" ]]; then
  ensure_vault_repo "$HOME/.local/state/obsidian-vault.git" "$HOME/ObsidianVault" <<'EXCL'
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
EXCL
  enable_timer vault-checkpoint.timer
else
  log_warn "Vault não encontrado em $HOME/ObsidianVault; pulando."
fi

# 2. Vaults extras (um .env por instância) -----------------------------------
for env_file in "$HOME"/.config/vault-checkpoint/*.env; do
  [[ -f "$env_file" ]] || continue
  name=$(basename "$env_file" .env)
  VAULT_GIT_DIR="" VAULT_WORK_TREE="" VAULT_PUSH_REMOTE="" VAULT_REMOTE_URL=""
  # shellcheck disable=SC1090
  . "$env_file"

  log_info "--- Vault '$name' ---"
  if [[ -z "$VAULT_WORK_TREE" || ! -d "$VAULT_WORK_TREE" ]]; then
    log_optional "Vault '$name' não existe nesta máquina (${VAULT_WORK_TREE:-?}); pulando."
    continue
  fi

  ensure_vault_repo "$VAULT_GIT_DIR" "$VAULT_WORK_TREE" <<'EXCL'
# Gerado por dotfiles/vault/hooks/setup.sh — edições serão sobrescritas.

# Metadata do Syncthing (na raiz e dentro de cada pasta aninhada)
.stfolder/
.stversions/
.stignore

# Estado por máquina, nunca sincronizado
/.obsidian/
/.trash/
/.claude/
CLAUDE.local.md
*.lock
.DS_Store
EXCL

  if [[ -n "$VAULT_PUSH_REMOTE" && -n "$VAULT_REMOTE_URL" ]]; then
    if git --git-dir="$VAULT_GIT_DIR" remote get-url "$VAULT_PUSH_REMOTE" &>/dev/null; then
      log_success "Remoto '$VAULT_PUSH_REMOTE' já configurado"
    else
      git --git-dir="$VAULT_GIT_DIR" remote add "$VAULT_PUSH_REMOTE" "$VAULT_REMOTE_URL"
      log_success "Remoto '$VAULT_PUSH_REMOTE' -> $VAULT_REMOTE_URL"
    fi
  fi

  enable_timer "vault-checkpoint@$name.timer"
done
