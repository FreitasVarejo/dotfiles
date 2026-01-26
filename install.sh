#!/bin/bash

# Cores para o output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sem Cor

DOTFILES_DIR=$(pwd)
BACKUP_DIR="$HOME/dotfiles_old_$(date +%Y%m%d_%H%M%S)"

echo -e "${BLUE}Iniciando a instalação dos dotfiles...${NC}"

# Função para criar links simbólicos com backup
link_file() {
    local src=$1
    local dest=$2

    # Verifica se o destino já existe
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        # Se já for um link simbólico apontando para o lugar certo, ignora
        if [ "$(readlink -f "$dest")" == "$src" ]; then
            echo -e "${YELLOW}Aviso:${NC} $dest já está vinculado corretamente. Pulando..."
            return
        fi

        # Cria pasta de backup se não existir
        mkdir -p "$BACKUP_DIR"
        echo -e "${YELLOW}Fazendo backup de:${NC} $dest -> $BACKUP_DIR/"
        mv "$dest" "$BACKUP_DIR/"
    fi

    # Cria o link simbólico
    echo -e "${GREEN}Vinculando:${NC} $dest -> $src"
    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
}

# --- Execução dos Links ---

# Neovim
link_file "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"

# Tmux
link_file "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"

# Bash
link_file "$DOTFILES_DIR/bash/bashrc" "$HOME/.bashrc"

# Git
link_file "$DOTFILES_DIR/git/gitconfig" "$HOME/.gitconfig"

echo -e "${BLUE}Instalação concluída!${NC}"
echo -e "${GREEN}Para aplicar as mudanças no bash agora, execute: ${YELLOW}source ~/.bashrc${NC}"
if [ -d "$BACKUP_DIR" ]; then
    echo -e "${YELLOW}Seus arquivos antigos foram salvos em: $BACKUP_DIR${NC}"
fi
