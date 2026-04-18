## Lua Linting & Formatting Setup

### Ferramentas Instaladas

- **Luacheck** (v1.2.0): Linter estático para Lua
  - Instalado via `luarocks install --local luacheck`
  - Disponível em: `~/.luarocks/bin/luacheck`

- **Stylua** (v2.3.1): Formatter para Lua
  - Já instalado via Mason (gerenciador Neovim)
  - Disponível em: `~/.local/share/nvim/mason/bin/stylua`

- **Luac**: Compilador Lua (padrão do sistema)
  - Valida sintaxe sem executar código

### Recursos

#### 1. **Linting Automático** (em tempo real)
- **Ativação**: Ao abrir arquivo `.lua` no Neovim
- **Gatilhos**:
  - `BufWritePost`: Ao salvar o arquivo
  - `BufReadPost`: Ao abrir arquivo
  - `InsertLeave`: Ao sair do modo insert
- **Configuração**: `lua/plugins/lua-lint.lua`
- **Erros detectados**:
  - Variáveis não utilizadas
  - Globais não definidas
  - Problemas de escopo
  - Erros de sintaxe

#### 2. **Formatação Automática** (ao salvar)
- **Ativação**: Ao salvar arquivo `.lua` (se existir)
- **Formatter**: Stylua
- **Configuração**: `lua/plugins/format-lint.lua`
- **Comportamento**:
  - Ativa automaticamente ao salvar
  - Timeout de 500ms
  - Fallback para LSP se stylua falhar

#### 3. **Verificação Manual**

**Linting com luacheck:**
```bash
luacheck /path/to/file.lua
luacheck /path/to/directory/  # recursivo
```

**Compilação/validação de sintaxe:**
```bash
luac -p /path/to/file.lua
```

**Formatação com stylua:**
```bash
~/.local/share/nvim/mason/bin/stylua /path/to/file.lua
stylua --check /path/to/file.lua  # apenas verifica
```

### Configuração do Projeto

#### `.luacheckrc`
Define as regras de linting:
- Modo standard (warnings + erros)
- Avisos sobre globais não definidas
- Reconhece globals do Neovim (`vim.*`)
- Ignora variáveis de linha muito longa

### Como Usar

#### 1. **Editar arquivo Lua no Neovim**
```vim
:edit lua/config/options.lua
```
- Erros/warnings aparecem em tempo real
- Gutter indica problemas (`:Trouble` para ver detalhes)
- Salvar = formata automaticamente com stylua

#### 2. **Verificar código antes de commitar**
```bash
# Linting
~/.luarocks/bin/luacheck lua/

# Compilação
for f in lua/**/*.lua; do luac -p "$f" || exit 1; done
```

#### 3. **Integrar em CI/CD**
Adicionar ao `.github/workflows/lint.yml`:
```yaml
- name: Lint Lua
  run: ~/.luarocks/bin/luacheck lua/

- name: Check Lua compilation
  run: find lua -name "*.lua" -exec luac -p {} \;
```

### Dicas

- **Variáveis não usadas**: Prefixe com `_` para ignorar
  ```lua
  local _unused = "won't trigger warning"
  ```

- **Globais customizadas**: Editar `.luacheckrc` se necessário
  ```lua
  globals = {
    "my_custom_global",
  }
  ```

- **Desabilitar para linha específica**: Comentário especial
  ```lua
  -- luacheck: ignore undefined_var
  local result = undefined_var + 1
  ```

### Arquivos Relevantes

- `.luacheckrc` - Configuração global de linting
- `lua/plugins/lua-lint.lua` - Integração nvim-lint
- `lua/plugins/format-lint.lua` - Integração conform.nvim

### Versões

- Lua: 5.4.8
- Luacheck: 1.2.0
- Stylua: 2.3.1
