#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO] $1${NC}"; }
log_success() { echo -e "${GREEN}[OK] $1${NC}"; }
log_warn() { echo -e "${YELLOW}[MISSING] $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}"; }

echo "=== Dotfiles Healthcheck ==="
echo "Verificando se as ferramentas necessárias estão instaladas..."
echo ""

ALL_GOOD=true

check_cmd() {
  local cmd_name=$1
  local install_hint=$2
  shift 2
  local alternatives=("$@")

  if command -v "$cmd_name" &>/dev/null; then
    log_success "$cmd_name encontrado: $(command -v "$cmd_name")"
  else
    log_warn "$cmd_name não encontrado."
    for i in "{alternatives[@]}"; do
      if command -v "$alt" &>/dev/null; then
        log_info "  -> Nota: O programa está instalado como '$alt' (considere criar um alias ou link simbólico)."
      fi
    done
    if [ -n "$install_hint" ]; then
      echo "    -> Sugestão: $install_hint"
    fi
    ALL_GOOD=false
  fi
}

log_info "--- Ferramentas do Sistema ---"
check_cmd "git" "sudo apt install git"
check_cmd "stow" "sudo apt install stow"
check_cmd "curl" "sudo apt install curl"
check_cmd "make" "sudo apt install build-essential / xcode-select --install"
check_cmd "gcc" "sudo apt install build-essential"

echo ""

log_info "--- Ferramentas CLI ---"
check_cmd "tmux" "sudo apt install tmux"
check_cmd "rg" "sudo apt install ripgrep"
check_cmd "fd" "sudo apt isntall fd-find (depois linkar fdfind -> fd)" "fd"
check_cmd "bat" "sudo apt install bat (depois linkar batcat->bat)" "batcat"
check_cmd "fzf" "git clone --depth 1 https://github.com/junegunn/fzf.git ~/.config/fzf && ~/.config/fzf/install"
check_cmd "zoxide" "curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash"
check_cmd "starship" "curl -sS https://starship.rs/install.sh | sh"

echo ""

log_info "--- Neovim ---"
if command -v nvim &>/dev/null; then
  NVIM_VER=$(nvim --version | head -n1 | cut -d ' ' -f2)
  CLEAN_VER="${NVIM_VER#v}"

  MAJOR=$(echo "$CLEAN_VER" | cut -d. -f1)
  MINOR=$(echo "$CLEAN_VER" | cut -d. -f2)

  if [ "$MAJOR" -gt 0 ] || ([ "$MAJOR" -eq 0 ] && [ "$MINOR" -ge 9 ]); then
    log_success "Neovim encontrado ($NVIM_VER)"
  else
    log_warn "Neovim encontrado, mas versão antiga ($NVIM_VER). Recomendado v0.9+"
  fi
else
  log_warn "Neovim não encontrado."
  echo "    -> Sugestão: Baixar a release mais recente do Github (v0.9+)"
  ALL_GOOD=false
fi

echo ""

log_info "--- Tmux Plugin Manager (TPM) ---"
if [ -d "$HOME/.config/tmux/plugins/tpm" ]; then
  log_success "TPM encontrado."
else
  log_warn "TPM não encontrado."
  echo "    -> Executar: git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm"
  ALL_GOOD=false
fi

echo ""

log_info "--- Git Identity ---"
git_name=$(git config --global user.name 2>/dev/null)
git_email=$(git config --global user.email 2>/dev/null)

if [ -n "$git_name" ] && [ -n "$git_email" ]; then
  log_success "Git identity configurada: $git_name <$git_email>"
else
  log_warn "Git identity não configurada (user.name / user.email ausentes)."
  echo ""
  echo "    Digite seu nome completo (sem acentos ou caracteres especiais, ex: sem 'ç'):"
  read -r full_name
  echo "    Digite seu email (o mesmo da sua conta GitHub):"
  read -r email
  git config --global user.name "$full_name"
  git config --global user.email "$email"
  log_success "Git identity configurada: $full_name <$email>"
fi

echo ""

if [ "$ALL_GOOD" = true ]; then
  echo -e "${GREEN} Tudo parece estar correto! Você pode rodar ./setup.sh agora.${NC}"
else
  echo -e "${RED} Faltam dependências.${NC}"
  echo "Por favor, instale as ferramentas listadas como [MISSING] acima antes de rodar ./setup.sh para garantir a melhor experiência."
fi
