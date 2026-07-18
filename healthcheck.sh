#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO] $1${NC}"; }
log_success() { echo -e "${GREEN}[OK] $1${NC}"; }
log_warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
log_missing() { echo -e "${YELLOW}[MISSING] $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}"; }
log_optional() { echo -e "${BLUE}[OPTIONAL] $1${NC}"; }

echo "=== Dotfiles Healthcheck ==="
echo "Verificando se as ferramentas necessárias estão instaladas..."
echo ""

ALL_GOOD=true

check_cmd() {
  local cmd_name=$1
  local install_hint=$2
  local optional="${3:-no}"
  shift 3 2>/dev/null || shift 2
  local alternatives=("$@")

  if command -v "$cmd_name" &>/dev/null; then
    log_success "$cmd_name encontrado: $(command -v "$cmd_name")"
  else
    if [ "$optional" = "optional" ]; then
      log_optional "$cmd_name não encontrado (opcional)."
    else
      log_missing "$cmd_name não encontrado."
    fi
    for alt in "${alternatives[@]}"; do
      if command -v "$alt" &>/dev/null; then
        log_info "  -> Nota: O programa está instalado como '$alt' (considere criar um alias ou link simbólico)."
      fi
    done
    if [ -n "$install_hint" ]; then
      echo "    -> Sugestão: $install_hint"
    fi
    if [ "$optional" != "optional" ]; then
      ALL_GOOD=false
    fi
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

# fd com checagem de versão (Snacks picker exige >= 8.4 para novos sintaxes).
if command -v fd &>/dev/null; then
    FD_VER=$(fd --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
    if [ -n "$FD_VER" ]; then
        FD_MAJOR=$(echo "$FD_VER" | cut -d. -f1)
        FD_MINOR=$(echo "$FD_VER" | cut -d. -f2)
        if [ "$FD_MAJOR" -lt 8 ] || { [ "$FD_MAJOR" -eq 8 ] && [ "$FD_MINOR" -lt 4 ]; }; then
            log_warn "fd encontrado ($FD_VER) mas versão < 8.4 — Snacks picker pode falhar."
            echo "    -> Atualizar fd: sudo apt install fd-find (Ubuntu 22.04+) ou compile from source."
        else
            log_success "fd encontrado: $FD_VER ($(command -v fd))"
        fi
    else
        log_success "fd encontrado: $(command -v fd)"
    fi
else
    check_cmd "fd" "sudo apt install fd-find (depois linkar fdfind -> fd)" "fdfind"
fi

check_cmd "bat" "sudo apt install bat (depois linkar batcat->bat)" "batcat"
check_cmd "fzf" "git clone --depth 1 https://github.com/junegunn/fzf.git ~/.config/fzf && ~/.config/fzf/install"
check_cmd "zoxide" "curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash"
check_cmd "starship" "curl -sS https://starship.rs/install.sh | sh"
check_cmd "yazi" "curl -sS https://yazi-rs.github.io/install.sh | bash (ou via gerenciador de pacotes)"

echo ""

log_info "--- Neovim ---"
if command -v nvim &>/dev/null; then
  NVIM_VER=$(nvim --version | head -n1 | cut -d ' ' -f2)
  CLEAN_VER="${NVIM_VER#v}"

  MAJOR=$(echo "$CLEAN_VER" | cut -d. -f1)
  MINOR=$(echo "$CLEAN_VER" | cut -d. -f2)

  if [ "$MAJOR" -gt 0 ] || { [ "$MAJOR" -eq 0 ] && [ "$MINOR" -ge 9 ]; }; then
    log_success "Neovim encontrado ($NVIM_VER)"
  else
    log_warn "Neovim encontrado, mas versão antiga ($NVIM_VER). Recomendado v0.9+"
  fi
else
  log_missing "Neovim não encontrado."
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

log_info "--- Node.js / NVM ---"
if [ -d "$HOME/.nvm" ]; then
    if command -v node &>/dev/null; then
        NODE_VER=$(node --version)
        log_success "Node.js encontrado: $NODE_VER via NVM"
    else
        log_warn "NVM instalado mas Node.js não encontrado."
        echo "    -> Execute: nvm use default (o lazy-load no .bashrc vai carregar nvm na primeira chamada)"
    fi
else
    log_warn "NVM não encontrado."
    echo "    -> Instalar: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
fi

echo ""

log_info "--- .NET SDK ---"
if [ -d "$HOME/.dotnet" ]; then
    log_success ".NET SDK encontrado em ~/.dotnet"
    ROSLYN_BIN=""
    for cand in \
        "$HOME/.local/share/nvim/mason/bin/roslyn" \
        "$HOME/.local/share/nvim/mason/bin/roslyn-language-server"; do
        if [ -x "$cand" ]; then
            ROSLYN_BIN="$cand"
            break
        fi
    done
    if [ -z "$ROSLYN_BIN" ]; then
        ROSLYN_BIN=$(command -v roslyn 2>/dev/null || command -v roslyn-language-server 2>/dev/null || true)
    fi
    if [ -n "$ROSLYN_BIN" ]; then
        log_success "Roslyn LSP disponível: $ROSLYN_BIN"
    else
        log_warn "Roslyn não encontrado (C# no Neovim ficará sem LSP)."
        echo "    -> Instalar via Mason: nvim --headless '+MasonInstall roslyn' +qa"
        echo "    -> Ou dotnet tool install --global csharp-ls"
    fi
else
    log_warn ".NET SDK não encontrado."
    echo "    -> Instalar: https://dotnet.microsoft.com/download"
fi

echo ""

log_info "--- Tree-sitter CLI ---"
if command -v tree-sitter &>/dev/null; then
    TS_VER=$(tree-sitter --version 2>&1 | head -n1)
    log_success "Tree-sitter CLI encontrado: $TS_VER"
else
    log_warn "tree-sitter CLI não encontrado."
    echo "    -> Baixe binário de: https://github.com/tree-sitter/tree-sitter/releases"
    echo "    -> Ou execute: cargo install tree-sitter-cli"
fi

echo ""

log_info "--- Yazi Flavor ---"
if [ -d "$HOME/.config/yazi/flavors/catppuccin-mocha.yazi" ]; then
    log_success "Flavor catppuccin-mocha instalado"
else
    log_warn "Flavor catppuccin-mocha não encontrado."
    echo "    -> Execute: cd ~/dotfiles/yazi && ya pkg install"
fi

echo ""

log_info "--- Neovim smoke (LazyVim/Mason/Snacks warmup) ---"
if command -v nvim &>/dev/null; then
    if timeout 90 nvim --headless \
        -c 'lua require("lazy").load({ plugins = { "folke/snacks.nvim" } })' \
        -c 'lua local ok, snacks = pcall(require, "snacks"); if ok then pcall(function() snacks.picker.smart() end) end' \
        -c 'qa' >/tmp/nvim-smoke.log 2>&1; then
        log_success "Smoke test do Neovim completou sem timeout."
        if grep -qiE 'E5113|fd < 8\.4|fd.*not found' /tmp/nvim-smoke.log; then
            log_warn "Possível incompatibilidade de fd com Snacks picker detectada (ver /tmp/nvim-smoke.log)."
        fi
    else
        log_warn "Smoke test excedeu timeout (90s). Pode ser primeira execução do Mason."
        echo "    -> Tente novamente após: nvim --headless '+Mason' +qa"
    fi
    rm -f /tmp/nvim-smoke.log
else
    log_info "Smoke pulado (nvim ausente)."
fi

echo ""

log_info "--- Snacks.image optionals (preview de imagens inline) ---"
log_optional "Estes são opcionais; o picker e dashboard funcionam sem eles."
check_cmd "magick" "sudo apt install imagemagick" "optional"
check_cmd "gs" "sudo apt install ghostscript" "optional"
check_cmd "tectonic" "cargo install tectonic" "optional"
check_cmd "mndc" "cargo install mandown" "optional"

echo ""

if [ "$ALL_GOOD" = true ]; then
  echo -e "${GREEN} Tudo parece estar correto! Você pode rodar ./setup.sh agora.${NC}"
else
  echo -e "${RED} Faltam dependências.${NC}"
  echo "Por favor, instale as ferramentas listadas como [MISSING] acima antes de rodar ./setup.sh para garantir a melhor experiência."
fi
