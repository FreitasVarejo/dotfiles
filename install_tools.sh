#!/bin/bash

set -e

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}>>> Iniciando instalação de ferramentas modernas...${NC}"

# Detecta Arquitetura
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    NVIM_ARCH="linux64"
elif [ "$ARCH" = "aarch64" ]; then
    NVIM_ARCH="linux-arm64"
else
    echo -e "${YELLOW}Arquitetura $ARCH não suportada automaticamente para Neovim.${NC}"
    NVIM_ARCH=""
fi

# Cria diretório local para binários se não existir
mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

# --- 1. Neovim (Latest Stable) ---
echo -e "${YELLOW}Verificando Neovim...${NC}"
NEED_NVIM=true
if command -v nvim &> /dev/null; then
    CURRENT_VER=$(nvim --version | head -n1 | cut -d ' ' -f2)
    # Verifica se é versão >= 0.9.0 (simplificado)
    if [[ "$CURRENT_VER" > "v0.9.0" ]]; then
        echo -e "${GREEN}Neovim já está atualizado ($CURRENT_VER).${NC}"
        NEED_NVIM=false
    fi
fi

if [ "$NEED_NVIM" = true ] && [ -n "$NVIM_ARCH" ]; then
    echo -e "${BLUE}Instalando Neovim (Latest Stable) para $ARCH...${NC}"
    # Baixa a versão compilada (appimage ou tarball)
    FILENAME="nvim-${NVIM_ARCH}.tar.gz"
    URL="https://github.com/neovim/neovim/releases/latest/download/$FILENAME"
    
    echo "Baixando de: $URL"
    curl -LO "$URL"
    
    # Remove instalação anterior em .local se existir
    rm -rf "$HOME/.local/nvim-${NVIM_ARCH}"
    
    # Extrai
    tar xf "$FILENAME" -C "$HOME/.local"
    rm "$FILENAME"
    
    # Link simbólico
    ln -sf "$HOME/.local/nvim-${NVIM_ARCH}/bin/nvim" "$HOME/.local/bin/nvim"
    echo -e "${GREEN}Neovim instalado em ~/.local/bin/nvim${NC}"
fi

# --- 2. Starship ---
if ! command -v starship &> /dev/null; then
    echo -e "${BLUE}Instalando Starship...${NC}"
    curl -sS https://starship.rs/install.sh | sh -s -- -y --bin-dir "$HOME/.local/bin"
else
    echo -e "${GREEN}Starship já instalado.${NC}"
fi

# --- 3. Zoxide ---
if ! command -v zoxide &> /dev/null; then
    echo -e "${BLUE}Instalando Zoxide...${NC}"
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
else
    echo -e "${GREEN}Zoxide já instalado.${NC}"
fi

# --- 4. FZF ---
if ! command -v fzf &> /dev/null; then
    echo -e "${BLUE}Instalando FZF...${NC}"
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install --all --no-bash --no-zsh --no-fish  # Apenas binários, bashrc já configuramos
else
    echo -e "${GREEN}FZF já instalado.${NC}"
fi

# --- 5. Rust Tools (Ripgrep, Bat, Delta) ---
# Tenta instalar via apt se tiver sudo, senão avisa
if command -v sudo &> /dev/null; then
    echo -e "${YELLOW}Tentando instalar ripgrep, bat e git-delta via apt...${NC}"
    sudo apt-get update -y
    sudo apt-get install -y ripgrep bat git-delta || echo -e "${YELLOW}Falha no apt, verifique manualmente.${NC}"
    
    # Fix para o bat (no ubuntu chama batcat)
    if command -v batcat &> /dev/null && ! command -v bat &> /dev/null; then
        ln -sf "$(which batcat)" "$HOME/.local/bin/bat"
    fi
else
    echo -e "${YELLOW}Sudo não disponível. Pulei ripgrep/bat/delta. Instale manualmente ou via cargo.${NC}"
fi

# --- 6. Tmux Plugin Manager ---
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    echo -e "${BLUE}Instalando TPM (Tmux Plugin Manager)...${NC}"
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

echo -e "${GREEN}>>> Instalação concluída! Reinicie o terminal.${NC}"
