#!/bin/bash
# shellcheck shell=bash
#
# Orquestrador de deploy. Para cada pacote em STOW_TARGETS: faz backup de
# conflitos, aplica o stow e, se existir, roda <pkg>/hooks/setup.sh (que pode
# mutar estado — registrar MCP servers, configurar git identity, etc.).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

BACKUP_DIR="$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
HAS_BACKUP=false

# Mapa pacote -> diretório de destino do stow. Única fonte de verdade dos
# pacotes; os hooks (check/setup) vivem dentro de cada pasta de pacote.
declare -A STOW_TARGETS
STOW_TARGETS=(
  [bash]="$HOME"
  [conda]="$HOME"
  [tmux]="$HOME/.config/tmux"
  [nvim]="$HOME/.config/nvim"
  [git]="$HOME/.config/git"
  [yazi]="$HOME/.config/yazi"
  [opencode]="$HOME/.config/opencode"
  [vault]="$HOME"
)

if ! command -v stow &>/dev/null; then
  log_error "Stow is not installed."
  exit 1
fi

backup_path() {
  local target="$1"
  local label="${2:-backup}"

  if [[ -e "$target" || -h "$target" ]]; then
    # Resolve o path real independente de o symlink estar no próprio $target
    # ou em algum diretório pai (stow faz "tree folding": quando não há
    # conflito, ele symlinka um diretório inteiro, ex: ~/.config/nvim/lua ->
    # dotfiles/nvim/lua). Checar só "-h \"$target\"" ignora esse segundo caso
    # e trata arquivos que já vivem dentro do repo como conflito, apagando-os
    # do repo ao mover para o backup.
    local resolved
    resolved=$(readlink -f "$target" 2>/dev/null)
    if [[ -n "$resolved" && "$resolved" == "$SCRIPT_DIR"* ]]; then
      return
    fi

    if [[ "$HAS_BACKUP" == false ]]; then
      mkdir -p "$BACKUP_DIR"
      HAS_BACKUP=true
    fi

    log_warn "Conflict detected at $label. Moving to backup..."
    mkdir -p "$BACKUP_DIR/$(dirname "$target" | sed "s|^$HOME/||")"
    mv "$target" "$BACKUP_DIR/${target#"$HOME"/}"
  fi
}

backup_home_package() {
  local pkg_name="$1"
  local pkg_path="$SCRIPT_DIR/$pkg_name"

  for item in "$pkg_path"/* "$pkg_path"/.*; do
    [[ "$(basename "$item")" == "." ]] && continue
    [[ "$(basename "$item")" == ".." ]] && continue
    [[ "$(basename "$item")" == "*" ]] && continue
    # Não faz backup do diretório de hooks (não é stowado).
    [[ "$(basename "$item")" == "hooks" ]] && continue

    [[ -e "$item" ]] || continue
    local rel_path
    rel_path=$(basename "$item")
    backup_path "$HOME/$rel_path" "~$rel_path"
  done
}

backup_xdg_package() {
  local pkg_name="$1"
  local local_target="${STOW_TARGETS[$pkg_name]}"
  local pkg_path="$SCRIPT_DIR/$pkg_name"

  while IFS= read -r -d '' file; do
    local rel_path="${file#"$pkg_path"/}"
    backup_path "$local_target/$rel_path" "$local_target/$rel_path"
  done < <(find "$pkg_path" -type f -not -path "$pkg_path/hooks/*" -print0 2>/dev/null | grep -vzE '\.md$')
}

run_package_setup_hook() {
  local pkg_name="$1"
  local hook="$SCRIPT_DIR/$pkg_name/hooks/setup.sh"

  [[ -f "$hook" ]] || return 0

  echo ""
  log_info "Rodando setup hook do pacote '$pkg_name'..."
  # Não deixa o hook derrubar o setup inteiro (set -e) se ele falhar.
  bash "$hook" || log_warn "Setup hook de '$pkg_name' retornou erro (continuando)."
}

log_info "Starting dotfiles deployment..."

for pkg_name in "${!STOW_TARGETS[@]}"; do
  local_target="${STOW_TARGETS[$pkg_name]}"

  log_info "Processing package: $pkg_name -> $local_target"

  if [[ "$local_target" == "$HOME" ]]; then
    backup_home_package "$pkg_name"
  else
    backup_xdg_package "$pkg_name"
    mkdir -p "$local_target"
  fi

  if stow -R -t "$local_target" "$pkg_name" 2>/dev/null; then
    log_success "Stowed $pkg_name"
  elif stow -t "$local_target" "$pkg_name" 2>/dev/null; then
    log_success "Stowed $pkg_name"
  else
    log_warn "Failed to stow $pkg_name"
  fi

  run_package_setup_hook "$pkg_name"
done

echo ""
if [[ "$HAS_BACKUP" == true ]]; then
  log_success "Deployment complete with backups!"
  echo "Old files moved to: $BACKUP_DIR"
else
  log_success "Deployment complete (no conflicts)."
fi
