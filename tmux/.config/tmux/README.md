# Tmux Configuration

Configuração otimizada de tmux com atalhos shell, tema Catppuccin e navegação vim-integrada.

## Estrutura

```
.config/tmux/
├── tmux.conf          # Configuração principal
├── README.md          # Este arquivo
└── plugins/           # Plugins gerenciados por TPM
    ├── tpm/           # Tmux Plugin Manager
    ├── tmux-sensible/ # Defaults sensatos
    ├── tmux-yank/     # Melhor integração com clipboard
    ├── vim-tmux-navigator/ # Navegação vim/tmux integrada
    └── catppuccin-tmux/    # Tema Catppuccin
```

## Quick Start

### Iniciar tmux
```bash
# Criar nova sessão
tmux new-session -s dev

# Ou usar o atalho shell (veja abaixo)
t n dev
```

### Keybindings Principais

**Prefix: `Ctrl+s`** (não `Ctrl+b`)

| Atalho | Ação |
|--------|------|
| `Ctrl+s` `\|` | Split vertical |
| `Ctrl+s` `-` | Split horizontal |
| `Ctrl+s` `r` | Reload config |
| `Ctrl+s` `h/j/k/l` | Navigate panes (vim-style) |
| `Ctrl+s` `-r` `H/J/K/L` | Resize panes |
| `Ctrl+s` `[` | Enter copy mode |
| `Ctrl+s` `v` | Begin selection (copy mode) |
| `Ctrl+s` `y` | Copy selection |
| `Ctrl+s` `d` | Detach session |

## Shell Shortcuts (t command)

Para acesso rápido sem digitar `tmux` o tempo todo, use os atalhos shell definidos em `bash/.bashrc.d/tmux-shortcuts.sh`:

### Listar Sessões
```bash
t              # Lista todas as sessões ativas
t ls           # Alias para listar
```

**Output:**
```
dev: 2 windows (created Sat Apr 11 09:34:39 2026)
web: 1 window (created Sat Apr 11 10:15:22 2026) (attached)
```

### Criar Sessão
```bash
t n dev        # Cria nova sessão chamada "dev"
t n web        # Cria nova sessão chamada "web"
```

Você entrará na sessão imediatamente.

### Conectar à Sessão
```bash
t a dev        # Attach à sessão "dev"
t a web        # Attach à sessão "web"

# Desconectar: Ctrl+s d
# Voltar para a sessão: t a dev
```

### Matar Sessão
```bash
t k dev        # Mata sessão "dev"
t kall         # Mata TODAS as sessões (cuidado!)
```

### Renomear Sessão
```bash
t rename dev development
t mv old new   # Alias
```

### Listar Janelas
```bash
t lw dev       # Lista janelas na sessão "dev"
t lw           # Lista janelas na sessão atual
```

### Ver Ajuda
```bash
t help
t h
```

## Autocomplete

Pressione `<TAB>` após digitar `t` para ver sugestões:

```bash
$ t <TAB>
a      h      k      kall   kill   lw     ls     n      rename send
```

Autocomplete também funciona para nomes de sessão:

```bash
$ t a <TAB>
dev        web        database
$ t a d<TAB>
dev
```

## Configuração

### Arquivo Principal: `tmux.conf`

Destaques da configuração:

- **Prefix: `Ctrl+s`** - Menos conflitos que `Ctrl+b`
- **UTF-8 Force: `-u`** - Unicode support completo
- **256 colors**: Suporte a cores true color
- **Mouse**: Habilitado para seleção/scroll
- **Vi Mode**: Copy mode usa keybindings vim

### Plugins

Plugins gerenciados automaticamente por **TPM** (Tmux Plugin Manager):

1. **tmux-sensible** - Defaults sensatos
2. **tmux-yank** - Melhor clipboard integration
3. **vim-tmux-navigator** - Navegação fluida entre vim e tmux
4. **catppuccin-tmux** - Tema Catppuccin (mocha flavor)

## Workflows Comuns

### Desenvolvimento Multi-Projeto

```bash
# Criar sessões para cada projeto
t n frontend
t n backend
t n database

# Trabalhar em paralelo
t a frontend    # Ctrl+s d para desconectar
t a backend     # Ctrl+s d
t a database

# Cleanup
t k frontend && t k backend && t k database
```

### Organizar Dentro de Uma Sessão

```bash
# Dentro de uma sessão (t n dev)
Ctrl+s -       # Split horizontal para segundo painel
Ctrl+s |       # Split vertical se quiser mais

# Navegar entre painéis
Ctrl+s h       # Painel esquerdo
Ctrl+s j       # Painel abaixo
Ctrl+s k       # Painel acima
Ctrl+s l       # Painel direito
```

### Copiar e Colar

```bash
# Dentro de tmux
Ctrl+s [       # Entra em copy mode
hjkl           # Navegar (vi-style)
v              # Begin selection
y              # Yank (copiar)

# Colar com mouse ou Ctrl+shift+v normalmente
```

## Customização

### Adicionar Novo Atalho Shell

Edite `bash/.bashrc.d/tmux-shortcuts.sh` e adicione um novo case:

```bash
t() {
  local cmd="${1:-}"
  
  case "$cmd" in
    # ... existing commands ...
    
    # Novo atalho
    custom|mycommand)
      local arg="${2:-}"
      # sua lógica aqui
      tmux -u seu-comando "$arg"
      ;;
  esac
}
```

Depois, atualize a completion em `bash/.bashrc.d/tmux-completion.sh` se necessário.

### Alterar Keybindings

Edite `tmux.conf`:

```bash
# Exemplo: mudar split-window binding
bind | split-window -h     # Vertical
bind - split-window -v     # Horizontal

# Depois reload
Ctrl+s r
```

### Mudar Tema

Em `tmux.conf`, altere:

```bash
set -g @catppuccin_flavour 'mocha'  # latte, frappe, macchiato, mocha
```

Reload com `Ctrl+s r`.

## Troubleshooting

### Atalhos `t` não funcionam
```bash
# Recarregue o shell
source ~/.bashrc

# Ou feche e reabra o terminal
```

### Colors não aparecem corretamente
```bash
# Certifique-se de que seu terminal suporta true color
echo $TERM
# Deve ser: xterm-256color, screen-256color, tmux-256color, etc.
```

### Copy/Paste não funciona
```bash
# Verifique se o clipboard está configurado
# macOS/Linux com xclip:
sudo apt install xclip

# Depois reload tmux
tmux source-file ~/.config/tmux/tmux.conf
```

### Vim-tmux-navigator não funciona
```bash
# Certifique-se de que está instalado em vim também
# Em seu init.vim/init.lua (Neovim):
# A integração já deve estar funcionando se vim-tmux-navigator está instalado
```

## Referência Rápida de Sessões

```bash
# Criar & Gerenciar
t n <name>           # Nova sessão
t a <name>           # Conectar
t k <name>           # Matar
t kall               # Matar tudo
t rename <old> <new> # Renomear

# Listar & Info
t                    # Listar sessões
t ls                 # Alias
t lw <name>          # Listar janelas

# Dentro do Tmux (com Ctrl+s prefix)
:list-sessions       # Listar
:new-window          # Nova janela
:select-window -t 1  # Ir para janela 1
:send-keys -t 0 "cmd" Enter  # Enviar comando
```

## Recursos Extras

- [Tmux Docs](https://github.com/tmux/tmux/wiki)
- [Catppuccin Theme](https://github.com/catppuccin/tmux)
- [Vim-Tmux-Navigator](https://github.com/christoomey/vim-tmux-navigator)
- [TPM (Tmux Plugin Manager)](https://github.com/tmux-plugins/tpm)

## Próximas Melhorias (TODO)

- [ ] Adicionar binding para criar janelas rapidamente (`t w`)
- [ ] Script de backup de layouts tmux
- [ ] Integration com session manager automático
- [ ] Monitoring de recursos na status bar

---

**Última atualização:** Abril 2026
