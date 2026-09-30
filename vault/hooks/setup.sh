#!/bin/bash
# shellcheck shell=bash
# Setup do pacote 'vault': cria os repositórios de checkpoints dos vaults do
# Obsidian (fora das pastas sincronizadas), ativa os timers que os alimentam e
# põe no lugar o freitask (clone do repo e a TUI compilada).
#
#   - vault pessoal (~/ObsidianVault)            -> vault-checkpoint.timer
#   - vaults extras (~/.config/vault-checkpoint/<nome>.env, stowados deste
#     pacote)                                     -> vault-checkpoint@<nome>.timer
#   - freitask: clone em $FREITASK_REPO e `cargo install` da TUI
#
# Idempotente: repetir não recria repo, não duplica exclude nem remoto, não
# mexe num clone existente e só recompila a TUI quando o fonte mudou.

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

# 3. Freitask: clone e TUI ----------------------------------------------------
# O clone é o motor da CLI `freitask` (este pacote stowa o shim). Se ele já
# existe, não é tocado: quem decide quando dar `git pull` é o usuário.
FREITASK_REPO="${FREITASK_REPO:-$HOME/dev/freitask.nvim}"
FREITASK_REMOTE="git@github.com:FreitasVarejo/freitask.nvim.git"

echo ""
log_info "--- Freitask ---"
if [[ -f "$FREITASK_REPO/lua/freitask/init.lua" ]]; then
  log_success "freitask já clonado: $FREITASK_REPO"
elif command -v git &>/dev/null; then
  mkdir -p "$(dirname "$FREITASK_REPO")"
  if git clone --quiet "$FREITASK_REMOTE" "$FREITASK_REPO"; then
    log_success "freitask clonado em $FREITASK_REPO"
  else
    log_warn "Falha ao clonar o freitask de $FREITASK_REMOTE"
  fi
else
  log_warn "git não encontrado; não foi possível clonar o freitask"
fi

# A TUI (`freitask` sem argumentos) é conveniência: sem ela a CLI segue
# inteira, então falta de cargo é aviso. Recompila só quando algum fonte é mais
# novo que o binário instalado — `cargo install` refaz o build toda vez.
TUI_SRC="$FREITASK_REPO/tui"
TUI_BIN="${CARGO_HOME:-$HOME/.cargo}/bin/freitask-tui"
if [[ ! -f "$TUI_SRC/Cargo.toml" ]]; then
  log_warn "Clone do freitask sem tui/ (desatualizado?); TUI não instalada"
elif ! command -v cargo &>/dev/null; then
  log_warn "cargo não encontrado; TUI do freitask não instalada"
  echo "    -> $PM_INSTALL cargo && ~/dotfiles/setup.sh"
elif [[ -x "$TUI_BIN" && -z "$(find "$TUI_SRC/src" "$TUI_SRC/Cargo.toml" "$TUI_SRC/Cargo.lock" -newer "$TUI_BIN" -print -quit)" ]]; then
  log_success "freitask-tui em dia: $TUI_BIN"
elif cargo install --quiet --locked --path "$TUI_SRC"; then
  log_success "freitask-tui instalado: $TUI_BIN"
else
  log_warn "cargo install da TUI falhou"
  echo "    -> Rode à mão para ver o erro: cargo install --locked --path \"$TUI_SRC\""
fi
