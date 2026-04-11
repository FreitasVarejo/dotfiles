# Nerd Fonts + Yazi no Fedora 41

## Status Current

✅ **Sistema está bem configurado:**
- Font cache limpo e reconstruído
- 96 variantes de JetBrains Mono Nerd Font detectadas e funcionais
- Locale UTF-8 correto (C.UTF-8)
- Terminal suporta 256 cores

## Problema Reportado

Você mencionou que **Nerd Fonts quebram algumas vezes no Yazi**, principalmente nos estilos. Isso pode ocorrer por:

### Causas Possíveis

1. **Fonte não configurada corretamente no terminal**
   - Seu emulador de terminal precisa estar usando JetBrains Mono Nerd Font
   - Diferentes terminais têm interfaces diferentes

2. **Problema com Wide Characters no Fedora 41**
   - Alguns symbols do Nerd Font são interpretados como "wide" (2 colunas)
   - Isso causa problemas de alinhamento no Yazi

3. **Font Fallback não configurado**
   - Se o Nerd Font não tem um character específico, o terminal tenta usar outra fonte
   - Isso causa mistura de estilos

### Solução Recomendada

#### Passo 1: Diagnosticar seu Terminal

```bash
# Descubra qual terminal você está usando
ps aux | grep -E "(gnome-terminal|alacritty|kitty|wezterm|xterm)" | grep -v grep

# Ou veja a variável
echo $TERM
```

#### Passo 2: Configurar a Fonte

**Se GNOME Terminal:**
- Preferences → Profiles → Font
- Selecione: "JetBrains Mono Nerd Font" ou "JetBrains Mono Nerd Font Mono"

**Se Alacritty:**
Edite `~/.config/alacritty/alacritty.toml`:
```toml
[font]
family = "JetBrainsMono Nerd Font"
# Ou tente Mono se houver problemas:
# family = "JetBrainsMonoNL Nerd Font Mono"
size = 12
```

**Se Kitty:**
Edite `~/.config/kitty/kitty.conf`:
```
font_family JetBrainsMono Nerd Font
# Ou:
# font_family JetBrainsMonoNL Nerd Font Mono
font_size 12
```

#### Passo 3: Testar

```bash
# Teste os symbols do Nerd Font
echo "  UI Icons: $(printf '\uf007 \uf086 \uf1d8 \uf0e0')"

# Abra o Yazi
yazi
```

### Se Ainda Houver Problemas

1. **Tente a variante Mono:**
   ```
   JetBrainsMonoNL Nerd Font Mono (mais compatível)
   JetBrainsMonoNerdFontMono-Regular
   ```

2. **Considere usar Hack Nerd Font como fallback:**
   - Ja temos HackNerdFont instalado também
   - Menos symbols, mas muito mais estável

3. **Desabilite ligaduras se houver:**
   - No seu terminal, procure por "Ligatures"
   - Desative se estiver ativado

## Ferramentas de Diagnóstico

### Health Check de Fonts
```bash
./healthcheck-fonts.sh
```

Este script verifica:
- ✅ Font cache
- ✅ Fontes JetBrains detectadas
- ✅ Fonts corrompidas
- ✅ Configuração de locale
- ✅ Suporte do terminal

### Listar Fonts Disponíveis
```bash
fc-list | grep -i "jetbrain\|hack"
```

### Testar Rendering
```bash
# Teste com diferentes symbols
printf '\ue0a0\ue0a1\ue0a2\ue0a3\n'  # Powerline
printf '\uf007\uf0e0\uf1d8\uf086\n'  # Misc
```

## Configuração do Tmux

Seu tmux já usa caracteres especiais (U+E0B6, U+E0B4). Se tiver problemas:

**Current tmux.conf usa:**
```
set -g @catppuccin_window_left_separator "<U+E0B6>"
set -g @catppuccin_window_right_separator "<U+E0B4>"
```

Se não renderizar bem, alterne para:
```
set -g @catppuccin_window_left_separator " "
set -g @catppuccin_window_right_separator " "
```

Ou use emojis:
```
set -g @catppuccin_window_left_separator "◀"
set -g @catppuccin_window_right_separator "▶"
```

## Próximas Ações

1. **Identifique seu terminal** - Qual emulador você usa?
2. **Configure a fonte** - Siga os passos acima para seu terminal específico
3. **Teste o Yazi** - Abra o Yazi e veja se renderiza corretamente
4. **Reporte problemas específicos** - Se ainda houver issues:
   - Qual caractere quebra?
   - Qual é o comportamento exato?
   - É intermitente ou consistente?

## Referências

- [Nerd Fonts - JetBrains Mono](https://www.nerdfonts.com/font-downloads)
- [Yazi - Requirements](https://yazi-rs.github.io/docs/tips#tmux)
- [Fedora 41 - Font Rendering](https://docs.fedoraproject.org/)
