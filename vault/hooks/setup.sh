#!/bin/bash
# shellcheck shell=bash
# Setup do pacote 'vault': cria os repositórios de checkpoints dos vaults do
# Obsidian (fora das pastas sincronizadas), ativa os timers que os alimentam e
# põe no lugar o freitask (clone do repo e o binário Rust compilado).
#
#   - vault pessoal (~/ObsidianVault)            -> vault-checkpoint.timer
#   - vaults extras (~/.config/vault-checkpoint/<nome>.env, stowados deste
#     pacote)                                     -> vault-checkpoint@<nome>.timer
#   - freitask: clone em $FREITASK_REPO, `git pull --ff-only` nele e `cargo install`
#     do binário (instala o rustup se o cargo faltar ou for velho)
#
# Idempotente: repetir não recria repo, não duplica exclude nem remoto, só
# avança o clone existente quando dá fast-forward limpo e só recompila o
# binário quando o fonte mudou.

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

# 3. Freitask: clone e binário ----------------------------------------------------
# O clone é o motor da CLI `freitask` (este pacote stowa o shim). Se ele já
# existe, `pull_freitask` o avança, mas só onde não atropela: é o clone de
# desenvolvimento do dono, então nada de pull com arquivo rastreado modificado,
# com HEAD solto ou em branch sem upstream. Fora isso, ou sem rede, é aviso: o
# setup nunca aborta por causa do pull.
FREITASK_REPO="${FREITASK_REPO:-$HOME/dev/freitask.nvim}"
FREITASK_REMOTE="git@github.com:FreitasVarejo/freitask.nvim.git"

# pull_freitask <repo>
pull_freitask() {
  local repo="$1" branch
  command -v git &>/dev/null && git -C "$repo" rev-parse --git-dir &>/dev/null || return 0
  if ! branch=$(git -C "$repo" symbolic-ref --short -q HEAD); then
    log_warn "freitask: HEAD solto em $repo; sem pull"
  elif ! git -C "$repo" diff --quiet || ! git -C "$repo" diff --cached --quiet; then
    log_warn "freitask: arquivos modificados em $repo; sem pull"
  elif ! git -C "$repo" rev-parse --abbrev-ref '@{u}' &>/dev/null; then
    log_warn "freitask: a branch '$branch' não tem upstream; sem pull"
  elif GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=5" \
    timeout 60 git -C "$repo" pull --ff-only --quiet 2>/dev/null; then
    log_success "freitask em dia com o origin ($(git -C "$repo" rev-parse --short HEAD))"
  else
    log_warn "freitask: git pull --ff-only falhou"
    echo "    -> Rode à mão para ver o erro: git -C \"$repo\" pull --ff-only"
  fi
}

echo ""
log_info "--- Freitask ---"
if [[ -d "$FREITASK_REPO/.git" || -f "$FREITASK_REPO/.git" ]]; then
  log_success "freitask já clonado: $FREITASK_REPO"
  pull_freitask "$FREITASK_REPO"
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

# O freitask é a CLI inteira (necessário, não conveniência): o binário Rust do
# crate crates/freitask, que também abre a TUI. O shim stowado só faz exec dele.
# Recompila só quando algum fonte é mais novo que o binário instalado —
# `cargo install` refaz o build toda vez. Falha aqui é aviso, nunca aborta.
FREITASK_SRC="$FREITASK_REPO/crates/freitask"
FREITASK_BIN="${CARGO_HOME:-$HOME/.cargo}/bin/freitask"

# cargo_meets <versão mínima>: o cargo do PATH existe e não é mais velho que ela.
cargo_meets() {
  local need="$1" have
  have=$(cargo --version 2>/dev/null | awk '{print $2}') || return 1
  [[ -n "$have" && "$(printf '%s\n%s\n' "$need" "$have" | sort -V | head -n1)" == "$need" ]]
}

# ensure_cargo <versão mínima>: deixa no PATH deste script um cargo que a
# atenda, instalando o rustup (ou atualizando a toolchain dele) se preciso.
ensure_cargo() {
  local need="$1" cargo_bin="${CARGO_HOME:-$HOME/.cargo}/bin"
  cargo_meets "$need" && return 0
  if command -v rustup &>/dev/null || [[ -x "$cargo_bin/rustup" ]]; then
    PATH="$cargo_bin:$PATH"
    log_info "toolchain do Rust abaixo de $need; rustup update stable"
    rustup update stable || return 1
  elif command -v curl &>/dev/null; then
    log_info "cargo ausente ou abaixo de $need; instalando o rustup"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal || return 1
    PATH="$cargo_bin:$PATH"
  else
    return 1
  fi
  cargo_meets "$need"
}

install_freitask() {
  local need
  if [[ ! -f "$FREITASK_REPO/Cargo.toml" ]]; then
    log_warn "Clone do freitask sem Cargo.toml (desatualizado?); binário não instalado"
    return 0
  fi
  if [[ -x "$FREITASK_BIN" && -z "$(find "$FREITASK_REPO/crates" "$FREITASK_REPO/Cargo.toml" "$FREITASK_REPO/Cargo.lock" -newer "$FREITASK_BIN" -print -quit)" ]]; then
    log_success "freitask em dia: $FREITASK_BIN"
    return 0
  fi
  need=$(sed -n 's/^rust-version *= *"\([^"]*\)".*/\1/p' "$FREITASK_REPO/Cargo.toml" | head -n1)
  if [[ -z "$need" ]]; then
    log_warn "freitask: rust-version não encontrado em $FREITASK_REPO/Cargo.toml; binário não instalado"
    return 0
  fi
  if ! ensure_cargo "$need"; then
    log_warn "Sem cargo $need ou mais novo; o freitask não foi instalado"
    echo "    -> Rode à mão: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal"
    echo "    -> Depois: ~/dotfiles/setup.sh"
    return 0
  fi
  if cargo install --quiet --locked --path "$FREITASK_SRC"; then
    log_success "freitask instalado: $FREITASK_BIN"
  else
    log_warn "cargo install do freitask falhou"
    echo "    -> Rode à mão para ver o erro: cargo install --locked --path \"$FREITASK_SRC\""
  fi
}
install_freitask
