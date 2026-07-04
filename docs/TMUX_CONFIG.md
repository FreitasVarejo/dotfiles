# Estrutura de Configuração do Tmux

## Arquivos de Configuração

```
.config/tmux/
├── tmux.conf          # 🎯 Configuração principal
├── colors.conf        # 🎨 Paleta de cores centralizada
├── theme.conf         # 🎭 Tema e estilos globais
├── statusline.conf    # 📊 Barra de status
├── utility.conf       # ⚙️  Bindings utilitários
└── plugins/
    └── tpm/           # Tmux Plugin Manager
```

## Descrição de cada arquivo

### `colors.conf` ⭐ NOVO
Paleta de cores centralizada baseada no **Solarized Dark**. Como o tmux não suporta variáveis em `set-option`, este arquivo contém apenas comentários com referências de cores reutilizáveis em toda a configuração.

**Estrutura:**
- **Cores base**: Solarized palette (base03 até base3)
- **Cores de acentuação**: yellow, orange, red, magenta, violet, blue, cyan, green
- **Paleta legada**: colour235, colour244, etc.

**Como usar:** Consulte este arquivo como referência ao editar tema e statusline.

### `theme.conf`
Importa `colors.conf` (para referência) e aplica o tema usando cores do Solarized. Define:
- Cores da statusbar e janelas
- Estilos de bordas dos panes
- Cores de mensagens e display de panes
- Configuração do relógio

**Todos os valores de cor estão documentados com comentários referenciando as cores do `colors.conf`.**

### `statusline.conf`
Configura a barra de status com cores Solarized. Inclui:
- Modo de cópia (selection highlighting)
- Estilos de mensagem
- Formato e cores da barra de status
- Formato de janelas ativas/inativas com path
- Status de atividade de janela

**Usa cores hex diretas com comentários explicativos.**

### `utility.conf`
Bindings e utilitários:
- `<prefix>-g`: Abre lazygit em popup (80% tamanho)
- `<prefix>-y`: Abre Claude Code em sessão separada

### `tmux.conf`
Configuração principal que:
1. Define prefixo e opções globais (`C-s`, escape-time, mouse, etc.)
2. Configura navegação, splits e redimensionamento
3. Carrega sub-arquivos em ordem correta
4. Carrega plugins (TPM)

## Como usar

### Adicionar/modificar cores
1. **Identifique a cor** que quer usar em `colors.conf`
2. **Edite** `theme.conf` ou `statusline.conf`
3. **Atualize** o valor hex direto (consulte o mapa em `colors.conf`)

Exemplo: Para usar `yellow (#b58900)` em um novo elemento:
```tmux
# Em theme.conf ou statusline.conf
set-option -g meu-estilo bg=#b58900,fg=#002b36
# ☝️  Valor vem de colors.conf (yellow: #b58900)
```

### Adicionar um novo estilo
1. Determine se é temático (vai em `theme.conf`) ou relacionado a statusline (vai em `statusline.conf`)
2. Use cores disponíveis em `colors.conf`
3. Adicione comentários explicativos
4. Teste com `<prefix>-r`

### Verificar sintaxe
```bash
tmux source-file ~/.config/tmux/tmux.conf
```

### Recarregar em tempo real
```tmux
<prefix>-r
```

## Paleta de cores Solarized Dark

| Nome | Hex | Colour | Uso |
|------|-----|--------|-----|
| base03 | #002b36 | 234 | Fundo principal |
| base02 | #073642 | 235 | Fundo secundário |
| base01 | #586e75 | - | Texto escuro |
| base0 | #839496 | - | Texto médio |
| base1 | #93a1a1 | - | Texto claro |
| base2 | #eee8d5 | - | Fundo claro |
| **yellow** | **#b58900** | **136** | Destaques |
| **orange** | #cb4b16 | 166 | Destaques alternos |
| blue | #268bd2 | 33 | Informações |
| green | #859900 | 64 | Sucesso |

## Notas de design

- **Consistência**: Todas as cores vêm do Solarized Dark para manter coesão visual
- **Legibilidade**: Cada arquivo tem seu propósito claramente definido
- **Manutenibilidade**: Documentação em comentários facilita futuras edições
- **Compatibilidade**: Suporta tanto hex (#eee8d5) quanto índices de cores (colour235)

