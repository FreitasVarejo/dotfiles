# Neovim Setup para React + Vite + TypeScript + Tailwind

## Configuração Completa ✅

Seu Neovim já possui tudo configurado para desenvolvimento React profissional.

### Ferramentas Instaladas

- **LSP**: vtsls (TypeScript Language Server)
- **Formatter**: Prettier
- **Linter**: ESLint com eslint_d
- **CSS**: Tailwind CSS Language Server
- **Parser**: Tree-sitter (JSX, TSX, TypeScript)
- **Completions**: blink.cmp

### Keybindings

| Keybinding | Ação |
|-----------|------|
| `<leader>fm` | Format file com Prettier (Normal + Visual) |
| `<leader>el` | ESLint Fix All (Normal) |
| `<leader>ca` | Code Actions (LSP) |
| `<leader>cf` | Format (via conform) |

### Snippets Disponíveis

#### React Snippets (`react.snippets`)
- `rfc` - React Functional Component com TypeScript
- `rcc` - React Class Component
- `uh` - useState hook
- `uef` - useEffect hook
- `uctx` - useContext hook
- `ucb` - useCallback hook
- `uref` - useRef hook
- `umemo` - useMemo hook
- `ureducer` - useReducer hook

#### Vite Snippets (`vite.snippets`)
- `viteconfig` - Configuração Vite padrão
- `vitetsconfig` - Vite + TypeScript com proxy
- `viteenv` - Template .env
- `vitehot` - HMR accept
- `viteglob` - Glob import

#### TypeScript/JavaScript Snippets (`typescript.snippets`)
- **Imports**: `imp`, `indef`, `imn`, `imns`
- **Exports**: `exp`, `exn`, `exf`
- **Console**: `conl`, `coner`, `conw`, `conti`
- **Functions**: `asyncfn`, `awaiter`, `arrowfn`, `arrow`
- **Loops**: `forof`, `forin`, `foreach`, `map`, `filter`, `reduce`
- **Objetos**: `objdes`, `arrdes`, `spread`, `rest`
- **Control**: `ifelse`, `ternary`, `switchcase`, `trycatch`
- **Async**: `promise`, `thenCatch`
- **Classes**: `classbase`, `classext`
- **TypeScript**: `interfaces`, `type`, `generic`, `uniontype`, `intersection`, `partial`, `record`

### Setup para Novo Projeto React

```bash
# 1. Criar projeto Vite + React
npm create vite@latest my-app -- --template react-ts
cd my-app

# 2. Instalar dependências
npm install

# 3. Instalar ferramentas de desenvolvimento
npm install -D eslint @typescript-eslint/eslint-plugin @typescript-eslint/parser
npm install -D eslint-plugin-react eslint-plugin-react-hooks
npm install -D prettier eslint-config-prettier

# 4. Copiar configurações
# .eslintrc.json (na raiz do projeto)
# .prettierrc.json (na raiz do projeto)
# tailwind.config.js (se usar Tailwind)

# 5. Abrir no Neovim
nvim .
```

### Exemplos de Uso

#### Criar um componente React
```
:e src/components/Button.tsx
rfc<Tab>
# Preencher: ButtonProps, props, etc...
```

#### Formatar arquivo
```
:FormatBuffer
# ou
<leader>fm
```

#### ESLint Fix
```
<leader>el
```

#### Usar snippet
```
# Em insert mode, digitar o trigger e pressionar Tab
useState<Tab>
```

### Configuração ESLint

O arquivo `.eslintrc.json` inclui:
- ESLint recomendado
- React e React Hooks
- TypeScript
- Prettier integration
- Regras customizadas (no-console, no-unused-vars com _, etc)

### Configuração Prettier

O arquivo `.prettierrc.json` inclui:
- Print width: 100
- Tab width: 2
- Sem semicolons no final
- Single quotes
- Trailing commas (ES5)
- Arrow parens sempre

### Troubleshooting

**ESLint não está funcionando?**
```bash
# Reinstalar eslint_d
:MasonInstall eslint_d
```

**Prettier não formata?**
```bash
# Verificar conformação
:ConformInfo

# Reinstalar prettier
:MasonInstall prettier
```

**TypeScript LSP não está ativo?**
```bash
# Verificar status
:LspInfo

# Reinstalar TypeScript
:MasonInstall vtsls
```

**Snippets não aparecem?**
```bash
# Verificar configuração do blink.cmp
# Pressionar <C-Space> para ativar completions
```

### Plugins Utilizados

- **LazyVim**: Framework base
- **nvim-lspconfig**: Configuração LSP
- **blink.cmp**: Completions
- **conform.nvim**: Formatting
- **nvim-lint**: Linting
- **nvim-treesitter**: Parsing
- **nvim-ts-autotag**: Auto-close tags
- **mason.nvim**: Gerenciador de ferramentas

### Próximas Melhorias (Opcional)

1. Configurar GitHub Copilot (copilot.vim)
2. Adicionar testes com Jest (snippets + debugging)
3. Configurar git hooks com husky
4. Adicionar debugging com debugger
5. Customizar Tailwind IntelliSense

---

**Criado**: Abril 2026
**Neovim**: 0.11.6+
**Framework**: LazyVim
