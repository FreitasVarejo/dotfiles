#!/bin/bash

# --- Configuração ---
BACKUP_DIR="$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
HAS_BACKUP=false

# Cria diretório de backup apenas se necessário depois
# (mas precisamos do path agora)

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO] $1${NC}"; }
log_success() { echo -e "${GREEN}[OK] $1${NC}"; }
log_warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }

# --- Função de Backup ---
backup_file() {
  local rel_path="$1"
  local target="$HOME/$rel_path"

  # Se o arquivo/pasta alvo existe ou é um link quebrado
  if [ -e "$target" ] || [ -h "$target" ]; then

    # Verifica se já é um symlink apontando para ONDE DEVERIA (nosso dotfiles)
    # Isso evita backup desnecessário se rodar o script 2x
    local current_link_target
    if [ -h "$target" ]; then
      current_link_target=$(readlink -f "$target")
      local my_repo_path
      my_repo_path=$(pwd)

      if [[ "$current_link_target" == "$my_repo_path"* ]]; then
        # Já está linkado corretamente para este repo
        return
      fi
    fi

    # Se chegamos aqui, existe conflito. Backup!
    if [ "$HAS_BACKUP" = false ]; then
      mkdir -p "$BACKUP_DIR"
      HAS_BACKUP=true
    fi

    log_warn "Conflito detectado em ~/$rel_path. Movendo para backup..."

    # Cria a estrutura de pastas no backup (ex: .config/)
    mkdir -p "$BACKUP_DIR/$(dirname "$rel_path")"
    mv "$target" "$BACKUP_DIR/$rel_path"
  fi
}

# --- Check Inicial ---
if ! command -v stow &>/dev/null; then
  echo "Erro: Stow não está instalado."
  exit 1
fi

log_info "Iniciando configuração dos dotfiles..."

# --- Loop pelos pacotes ---
for package in */; do
  pkg_name="${package%/}"

  # Ignora arquivos/pastas que não são pacotes stow
  [[ "$pkg_name" == "healthcheck.sh" ]] && continue
  [[ "$pkg_name" == "install_tools.sh" ]] && continue
  [[ "$pkg_name" == "README.md" ]] && continue
  [[ "$pkg_name" == "setup.sh" ]] && continue
  [[ "$pkg_name" == "nvim-linux64.tar.gz" ]] && continue
  [[ "$pkg_name" == "."* ]] && continue # Ignora .git, etc
  [[ "$pkg_name" == "_"* ]] && continue

  log_info "Processando pacote: $pkg_name"

  # 1. Estratégia para pastas .config/APP (Link da pasta inteira é preferível)
  if [ -d "$pkg_name/.config" ]; then
    for config_app in "$pkg_name/.config"/*; do
      if [ -e "$config_app" ]; then
        app_name=$(basename "$config_app")
        backup_file ".config/$app_name"
      fi
    done
  fi

  # 2. Estratégia para arquivos na raiz do pacote (ex: .bashrc, .zshrc)
  # Itera ocultos e não ocultos
  for item in "$pkg_name"/* "$pkg_name"/.*; do
    base_name=$(basename "$item")

    # Filtros de exclusão
    [[ "$base_name" == "." ]] && continue
    [[ "$base_name" == ".." ]] && continue
    [[ "$base_name" == ".git" ]] && continue
    [[ "$base_name" == ".config" ]] && continue # Já tratado acima
    [[ "$base_name" == "*" ]] && continue       # Glob vazio

    [ -e "$item" ] || continue # Garante que arquivo existe

    backup_file "$base_name"
  done

  # Executa o Stow
  # -v: verbose, -R: restow (prune old links + stow new)
  stow -R "$pkg_name" 2>/dev/null || stow "$pkg_name"
done

echo ""
if [ "$HAS_BACKUP" = true ]; then
  log_success "Instalação concluída com backups!"
  echo "Arquivos antigos foram movidos para: $BACKUP_DIR"
else
  log_success "Instalação concluída (sem conflitos encontrados)."
fi
