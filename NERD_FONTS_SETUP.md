# Configuração de Nerd Fonts - Guia Prático

## Status Atual do Sistema

✅ **Seu sistema está bem configurado:**
- **Terminal:** GNOME Ptyxis
- **Fontes instaladas:** 96 variantes de JetBrains Mono Nerd Font
- **Locale:** C.UTF-8 (UTF-8 correto)
- **Suporte de cores:** 256 colors (tmux-256color)
- **Font configurada:** JetBrainsMono Nerd Font 12pt

## O que foram as Nerd Fonts?

Nerd Fonts são versões estendidas de fontes monospace que incluem ícones para:
- Ícones de arquivo/pasta (para Yazi, LSDeluxe)
- Símbolos de Git (para Starship, Tmux)
- Símbolos de linguagem de programação
- Símbolos de status e interface

Exemplos:
```
  (usuário)      (email)      (documento)      (configurações)
uf007            uf0e0        uf1d8            uf086
```

## Scripts Disponíveis

### `healthcheck-fonts.sh`
Verifica se as Nerd Fonts estão corretamente instaladas e funcionando.

```bash
./healthcheck-fonts.sh
```

Verifica:
- ✅ Font cache do sistema
- ✅ Variantes de JetBrains detectadas
- ✅ Fontes corrompidas
- ✅ Configuração de locale (UTF-8)
- ✅ Suporte do terminal

### `setup-ptyxis-font.sh`
Configura automaticamente Nerd Fonts no GNOME Ptyxis.

```bash
./setup-ptyxis-font.sh
```

O que faz:
1. Valida que as Nerd Fonts estão instaladas
2. Obtém o perfil padrão do Ptyxis
3. Configura JetBrainsMono Nerd Font como fonte monospace
4. Desabilita ligaduras (evita problemas de rendering)
5. Aplica via dconf (banco de dados GNOME)

## Configuração Manual por Terminal

### GNOME Ptyxis (GUI)

1. Abra o Ptyxis
2. Clique em ⚙️ (Preferences)
3. Vá para **Appearance**
4. Em **Font**, selecione:
   - **JetBrainsMono Nerd Font** (recomendado)
   - Ou **JetBrainsMonoNL Nerd Font Mono** (se tiver problemas)
5. Ajuste o tamanho conforme preferir (12pt é padrão)
6. Feche e reabra o terminal

### GNOME Ptyxis (CLI/dconf)

```bash
# Listar UUID do perfil
dconf read /org/gnome/Ptyxis/default-profile-uuid

# Configurar a fonte (substitua UUID se necessário)
UUID="d698cc16d079f80d757fb42d68594767"
dconf write /org/gnome/Ptyxis/Profiles/$UUID/monospace-font-name "'JetBrainsMono Nerd Font 12'"
dconf write /org/gnome/Ptyxis/Profiles/$UUID/enable-ligatures "false"
```

### Alacritty

Edite `~/.config/alacritty/alacritty.toml`:

```toml
[font]
family = "JetBrainsMono Nerd Font"
size = 12.0

# Desabilitar ligaduras (se houver problema de rendering)
[font.bold]
family = "JetBrainsMono Nerd Font"
weight = "Bold"
```

### Kitty

Edite `~/.config/kitty/kitty.conf`:

```conf
font_family      JetBrainsMono Nerd Font
font_size        12

# Desabilitar ligaduras
disable_ligatures never
```

### WezTerm

Edite `~/.config/wezterm/wezterm.lua`:

```lua
return {
  font = wezterm.font("JetBrainsMono Nerd Font"),
  font_size = 12.0,
}
```

### Tmux

O Tmux **não configura fonte** - usa a fonte do terminal host. Mas os caracteres especiais precisam da Nerd Font no terminal subjacente.

Seu `~/.config/tmux/tmux.conf` já está otimizado:
```tmux
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
```

## Testando

### Teste Rápido

```bash
# Símbolos básicos do Nerd Font
printf '\uf007 \uf086 \uf1d8 \uf0e0\n'

# Símbolos Powerline (usados em Tmux/Starship)
printf '\ue0a0\ue0a1\ue0a2\ue0a3\n'

# Teste no Yazi
yazi

# Teste no Tmux
tmux
```

### Verificar Fonte Ativa

```bash
# No Ptyxis, verifique qual fonte está sendo usada
dconf read /org/gnome/Ptyxis/Profiles/d698cc16d079f80d757fb42d68594767/monospace-font-name

# Listar todas as Nerd Fonts instaladas
fc-list | grep -i nerd

# Verificar especificamente JetBrains
fc-list | grep -i jetbrain
```

## Troubleshooting

### Símbolos aparecem como quadrados

**Causa:** Terminal não está usando Nerd Font

**Solução:**
1. Abra as preferências do seu terminal
2. Confirme que a fonte é **JetBrainsMono Nerd Font**
3. Se não aparecer na lista, execute `fc-cache -v ~/.local/share/fonts/`
4. Feche e reabra o terminal

### Símbolos desalinhados ou quebrando (especialmente no Yazi)

**Causa:** Wide character rendering - alguns símbolos ocupam 2 colunas em vez de 1

**Solução:**
1. Tente a variante **Mono** da fonte:
   - `JetBrainsMonoNL Nerd Font Mono`
   - `JetBrainsMonoNL NFM`

2. Verifique se ligaduras estão desabilitadas:
   ```bash
   dconf write /org/gnome/Ptyxis/Profiles/UUID/enable-ligatures "false"
   ```

3. Se ainda quebrar, use a fonte alternativa instalada:
   ```bash
   fc-list | grep -i hack
   ```
   E alterne para Hack Nerd Font (mais compatível, menos ícones)

### Font não aparece em Preferences

**Causa:** Cache de fonte desatualizado

**Solução:**
```bash
fc-cache -v ~/.local/share/fonts/
fc-cache -v /usr/share/fonts/

# Feche e reabra o terminal
```

### Tmux com símbolos estranhos

**Seu tmux.conf usa:**
```tmux
set -g @catppuccin_window_left_separator "<U+E0B6>"
set -g @catppuccin_window_right_separator "<U+E0B4>"
```

Se não renderizar:
- Certifique-se que o terminal host (Ptyxis) usa Nerd Font
- Alterne para emojis se necessário:
  ```tmux
  set -g @catppuccin_window_left_separator "◀"
  set -g @catppuccin_window_right_separator "▶"
  ```

## Referências

- [Nerd Fonts - Download](https://www.nerdfonts.com/font-downloads)
- [GNOME Ptyxis Docs](https://wiki.gnome.org/Apps/Ptyxis)
- [dconf - GNOME Configuration Database](https://wiki.gnome.org/Projects/dconf)
- [Yazi - Requirements](https://yazi-rs.github.io/docs/tips#tmux)

## Próximos Passos

1. ✅ Verifique com `./healthcheck-fonts.sh`
2. ✅ Configure com `./setup-ptyxis-font.sh` (ou manualmente)
3. ✅ Teste a renderização
4. ✅ Se houver problemas, consulte troubleshooting acima

**Bom uso das Nerd Fonts!** 🚀
