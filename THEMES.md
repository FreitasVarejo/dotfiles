# Machine-Specific Themes

Este dotfiles suporta customização automática de temas do Neovim e Tmux baseada no hostname da máquina.

## Configuração Atual

| Máquina | Hostname | Nvim | Tmux |
|---------|----------|------|------|
| Máquina Principal | `fedora-41` | Catppuccin Mocha | Catppuccin Mocha |
| Raspberry Pi | `pi02` | Catppuccin Macchiato | Catppuccin Macchiato |
| PC Trabalho | `BTGNOTE10113` | Catppuccin Frappe | Catppuccin Frappe |

### Descrição dos Flavors

- **Mocha**: Tons de cinza escuros e neutros. Ideal para ambiente com boa iluminação.
- **Macchiato**: Tons mais quentes e suaves. Melhor para ambientes com pouca luz (recomendado para Pi).
- **Frappe**: Tons azuis e profissionais. Bom contraste para uso intenso (recomendado para trabalho).

## Como Funciona

### Neovim (`nvim/.config/nvim/lua/plugins/colorscheme.lua`)

```lua
local function get_catppuccin_flavour()
  local hostname = vim.fn.hostname()
  
  local flavour_map = {
    ["fedora-41"] = "mocha",
    ["pi02"] = "macchiato",
    ["BTGNOTE10113"] = "frappe",
  }
  
  return flavour_map[hostname] or "mocha"
end
```

O tema é detectado automaticamente ao iniciar o Neovim.

### Tmux (`tmux/.config/tmux/tmux.conf`)

```tmux
%if "#{==:#{hostname},fedora-41}"
  set -g @catppuccin_flavour 'mocha'
%elif "#{==:#{hostname},pi02}"
  set -g @catppuccin_flavour 'macchiato'
%elif "#{==:#{hostname},BTGNOTE10113}"
  set -g @catppuccin_flavour 'frappe'
%else
  set -g @catppuccin_flavour 'mocha'
%endif
```

O tema é aplicado quando o tmux carrega a configuração.

## Adicionar ou Modificar Temas

### Para adicionar uma nova máquina:

1. **Descobrir o hostname:**
   ```bash
   hostname
   ```

2. **Editar `nvim/.config/nvim/lua/plugins/colorscheme.lua`:**
   ```lua
   flavour_map = {
     ["seu-hostname"] = "flavor-desejado",  -- latte, frappe, macchiato, mocha
   }
   ```

3. **Editar `tmux/.config/tmux/tmux.conf`:**
   ```tmux
   %elif "#{==:#{hostname},seu-hostname}"
     set -g @catppuccin_flavour 'flavor-desejado'
   ```

4. **Testar:**
   ```bash
   # Neovim
   nvim --headless "+checkhealth" +qa
   
   # Tmux
   tmux source-file ~/.config/tmux/tmux.conf
   ```

### Mudar o flavor de uma máquina existente:

Simplesmente edite os mesmos arquivos acima e altere o valor do flavor para o desejado.

## Flavors Disponíveis do Catppuccin

- `latte` - Light theme (não recomendado para dark mode)
- `frappe` - Dark with cool blues
- `macchiato` - Dark with warm tones  
- `mocha` - Dark with neutral grays

## Troubleshooting

**Tema não está mudando no Neovim:**
```bash
# Force reload plugins
rm -rf ~/.local/share/nvim/lazy/catppuccin
nvim  # Will re-download and apply the theme
```

**Tema não está mudando no Tmux:**
```bash
# Reload tmux config
tmux source-file ~/.config/tmux/tmux.conf

# Se estiver dentro de uma sessão tmux:
<prefix>r  # (Ctrl+s por padrão)
```

**Verificar hostname:**
```bash
hostname
# ou com domínio
hostname -f
```
