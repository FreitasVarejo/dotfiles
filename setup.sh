#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BACKUP_DIR="$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
HAS_BACKUP=false

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO] $1${NC}"; }
log_success() { echo -e "${GREEN}[OK] $1${NC}"; }
log_warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}"; }

declare -A STOW_TARGETS
STOW_TARGETS=(
    [bash]="$HOME"
    [conda]="$HOME"
    [tmux]="$HOME/.config/tmux"
    [nvim]="$HOME/.config/nvim"
    [git]="$HOME/.config/git"
    [yazi]="$HOME/.config/yazi"
    [opencode]="$HOME/.config/opencode"
)

if ! command -v stow &>/dev/null; then
    log_error "Stow is not installed."
    exit 1
fi

backup_path() {
    local target="$1"
    local label="${2:-backup}"

    if [[ -e "$target" || -h "$target" ]]; then
        if [[ -h "$target" ]]; then
            local current_target
            current_target=$(readlink -f "$target")
            if [[ "$current_target" == "$SCRIPT_DIR"* ]]; then
                return
            fi
        fi

        if [[ "$HAS_BACKUP" == false ]]; then
            mkdir -p "$BACKUP_DIR"
            HAS_BACKUP=true
        fi

        log_warn "Conflict detected at $label. Moving to backup..."
        mkdir -p "$BACKUP_DIR/$(dirname "$target" | sed "s|^$HOME/||")"
        mv "$target" "$BACKUP_DIR/${target#$HOME/}"
    fi
}

backup_home_package() {
    local pkg_name="$1"
    local pkg_path="$SCRIPT_DIR/$pkg_name"

    for item in "$pkg_path"/* "$pkg_path"/.*; do
        [[ "$(basename "$item")" == "." ]] && continue
        [[ "$(basename "$item")" == ".." ]] && continue
        [[ "$(basename "$item")" == "*" ]] && continue

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
        local rel_path="${file#$pkg_path/}"
        backup_path "$local_target/$rel_path" "$local_target/$rel_path"
    done < <(find "$pkg_path" -type f -print0 2>/dev/null | grep -vzE '\.md$')
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
done

echo ""
if [[ "$HAS_BACKUP" == true ]]; then
    log_success "Deployment complete with backups!"
    echo "Old files moved to: $BACKUP_DIR"
else
    log_success "Deployment complete (no conflicts)."
fi