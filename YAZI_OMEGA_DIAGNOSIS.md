# Diagnóstico - Problema de Omega/Phi no Yazi

## 🔍 Problema Identificado

Quando você abre o Yazi e seleciona itens (cor invertida), aparecem caracteres **Omega (Ω)** e **Phi (Φ)** ao lado dos ícones Nerd Font.

### Causa Raiz

**O problema NÃO é das Nerd Fonts - é do GNOME Ptyxis (VTE 0.78)**

Ptyxis usa a biblioteca **VTE** (Virtual Terminal Emulator) que tem uma limitação:
- **Não renderiza caracteres do Private Use Area (U+E000 - U+F8FF)**
- Nerd Fonts usam justamente esse range para ícones
- Quando o caractere cai em fallback, outros caracteres aparecem (Omega, Phi, etc)

## ✅ Confirmação

Testamos e confirmamos que:
- ✓ As Nerd Fonts estão **corretamente instaladas** (2.3MB, 11.756 glyphs)
- ✓ Os ícones **existem na fonte** (U+F007, U+F0E0, U+F07B, etc)
- ✓ Emojis renderizam normalmente (👤 ✉️ 📁)
- ✓ Caracteres do Private Use Area **não renderizam** no Ptyxis
- ✗ Ptyxis/VTE não consegue exibir os ícones Nerd Font

## 📋 Soluções Disponíveis

### Solução 1: Usar Emojis no Yazi (RECOMENDADO)

Criamos uma configuração que usa emojis em vez de Nerd Fonts:

```bash
# Já está em ~/.config/yazi/theme.toml
yazi
# Teste - não deve ter mais Omega/Phi
```

**Vantagens:**
- Funciona imediatamente no Ptyxis
- Emojis renderizam perfeitamente
- Fácil de customizar
- Sem dependência de fontes especiais

### Solução 2: Usar Outro Terminal Emulador

Se você puder usar **Alacritty**, **Kitty**, ou **WezTerm**:
- ✓ Todos suportam Nerd Fonts perfeitamente
- ✓ Renderizam caracteres do Private Use Area
- ✓ Problema desaparece completamente

```bash
# Instalar Alacritty (exemplo)
sudo dnf install alacritty

# Será necessário configurar:
# ~/.config/alacritty/alacritty.toml
```

### Solução 3: Esperar Atualização do VTE

VTE é mantido pelo GNOME. Versões futuras podem corrigir esse problema.

- **VTE atual:** 0.78.4
- **GNOME:** 47.6
- Check: https://gitlab.gnome.org/GNOME/vte

## 🔧 Configurações Aplicadas

1. **Fontconfig** (`~/.config/fontconfig/conf.d/50-nerd-fonts.conf`)
   - Prioridade para Nerd Fonts
   - Definição explícita do Private Use Area

2. **Yazi** (`~/.config/yazi/theme.toml`)
   - Configuração com emojis
   - Compatível com Ptyxis

3. **GNOME Ptyxis**
   - Fonte: 0xProto Nerd Font Mono
   - Ligaduras: desabilitadas
   - Line spacing: 1.2

## 📚 Referências

- [GNOME VTE Issues](https://gitlab.gnome.org/GNOME/vte/-/issues)
- [Yazi Configuration](https://yazi-rs.github.io/docs/configuration)
- [Nerd Fonts - Private Use Area](https://www.nerdfonts.com)

## ❌ O Que NÃO Funciona

Essas soluções **não funcionam** porque o problema está no VTE:
- ❌ Mudar a fonte Nerd Font (todas têm Private Use Area)
- ❌ Desabilitar ligaduras
- ❌ Ajustar line spacing
- ❌ Fontconfig customizado

O VTE simplesmente não renderiza esses caracteres.

## ✅ Próximos Passos

1. **Teste com emojis:**
   ```bash
   yazi
   # Navegue e veja se Omega/Phi desapareceu
   ```

2. **Se problema persistir:**
   - Confirme que está usando GNOME Ptyxis
   - Verifique VTE version: `ptyxis --version`

3. **Se quiser Nerd Fonts:**
   - Instale Alacritty ou outro terminal
   - Será necessário reconfigurar

---

**Conclusão:** O problema é uma limitação do GNOME Ptyxis/VTE, não das Nerd Fonts. A solução mais prática é usar emojis, que renderizam perfeitamente.
