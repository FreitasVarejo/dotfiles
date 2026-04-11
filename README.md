# Dotfiles

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

_Se houver itens marcados como [MISSING], instale-os manualmente._

3. Aplique as configurações (cria links simbólicos via stow):

```bash
chmod +x setup.sh
./setup.sh
```

Aviso: O script `setup.sh` criará backups automáticos de suas configurações atuais em uma pasta `~/dotfiles_old_...` antes de criar os links simbólicos.

---

## Configurar Nerd Fonts

Se você quer usar Nerd Fonts no seu terminal (recomendado para Yazi, Starship, etc):

### Diagnóstico Rápido

```bash
./healthcheck-fonts.sh
```

### Configuração Automática (GNOME Ptyxis)

```bash
chmod +x setup-ptyxis-font.sh
./setup-ptyxis-font.sh
```

Este script:
- ✅ Verifica se as Nerd Fonts estão instaladas
- ✅ Configura JetBrains Mono Nerd Font no GNOME Ptyxis
- ✅ Desabilita ligaduras (que causam problemas de renderização)
- ✅ Testa os símbolos do Nerd Font

### Configuração Manual por Terminal

**GNOME Ptyxis:**
- Preferences (⚙️) → Appearance → Font
- Selecione: "JetBrainsMono Nerd Font"

**Alacritty** (`~/.config/alacritty/alacritty.toml`):
```toml
[font]
family = "JetBrainsMono Nerd Font"
size = 12
```

**Kitty** (`~/.config/kitty/kitty.conf`):
```conf
font_family JetBrainsMono Nerd Font
font_size 12
```

**Tmux** (`~/.config/tmux/tmux.conf`):
```tmux
# Já configurado para usar Nerd Fonts
# Fonte renderiza via terminal host
set -g default-terminal "tmux-256color"
```

### Testar Rendering

```bash
# Símbolos Nerd Font
printf '\uf007 \uf086 \uf1d8 \uf0e0\n'

# Powerline (usados no Tmux/Starship)
printf '\ue0a0\ue0a1\ue0a2\ue0a3\n'
```

### Troubleshooting

Se os símbolos não renderizam corretamente:

1. **Feche e reabra o terminal** (as mudanças via dconf podem precisar reload)
2. **Verifique a fonte:** `fc-list | grep -i jetbrain`
3. **Limpe o cache de fontes:** `fc-cache -v ~/.local/share/fonts/`
4. **Tente a variante Mono:** Se JetBrainsMono não funcionar, use `JetBrainsMono Nerd Font Mono`
5. **Desabilite ligaduras** no seu terminal (se tiver opção)

Para mais detalhes, veja [NERD_FONTS_FEDORA41.md](NERD_FONTS_FEDORA41.md).
