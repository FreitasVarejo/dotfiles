# Dotfiles
### Minhas configurações personalizadas de terminal, que transporto entre máquinas diferentes
- **Neovim**: Configuração modular (LSP, Treesitter, Mason, CMP).
- **Tmux**: Otimizado para Neovim, suporte a True Color e tema Dracula.
- **Bash**: Configurações de ambiente e aliases.
- **Git**: Configurações globais básicas.

### Pré-requisitos
Antes de instalar, certifique-se de ter as seguintes ferramentas instaladas:
- **Core**: `git`, `curl`, `stow`
- **Compilação**: `gcc`, `make`
- **CLI**: `tmux`, `ripgrep` (rg), `fd`, `bat`, `fzf`
- **Shell UX**: `starship`, `zoxide`
- **Editor**: `neovim` (v0.9+)

### Como Instalar
Para aplicar estas configurações em uma nova máquina:

1. Clone o repositório:
```bash
git clone https://github.com/FreitasVarejo/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

2. Verifique se o ambiente está pronto:
```bash
chmod +x healthcheck.sh
./healthcheck.sh
```
*Se houver itens marcados como [MISSING], instale-os manualmente.*

3. Aplique as configurações (cria links simbólicos via stow):
```bash
chmod +x setup.sh
./setup.sh
```

Aviso: O script `setup.sh` criará backups automáticos de suas configurações atuais em uma pasta `~/dotfiles_old_...` antes de criar os links simbólicos.
