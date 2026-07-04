# 🎯 Neovim C# 12 / .NET 8 Setup - Guia de Referência

**Status:** ✅ Completamente configurado e testado  
**Neovim:** v0.12.2  
**.NET:** 8.0.119 (primário), 10.0.203 (preview)  
**LSP:** Roslyn 5.8.0

---

## 🚀 Comandos Rápidos

### Verificar Configuração
```vim
:LspStatus          " Mostrar status do LSP (Neovim 0.12+)
:DiagShow           " Mostrar diagnósticos do buffer atual
:DiagToggle         " Habilitar/desabilitar diagnósticos
```

### Keybindings C# / .NET

| Atalho | Ação |
|--------|------|
| `<leader>cs` | Build (`dotnet build`) |
| `<leader>cr` | Run (`dotnet run`) |
| `<leader>ct` | Tests (`dotnet test`) |
| `<leader>cc` | Clean (`dotnet clean`) |
| `<leader>ls` | Show LSP Status |

### Keybindings LSP (Padrão LazyVim)

| Atalho | Ação |
|--------|------|
| `gd` | Go to Definition |
| `gr` | Find References |
| `gI` | Goto Implementation |
| `gy` | Goto Type Definition |
| `K` | Hover Documentation |
| `<C-k>` | Signature Help |
| `<leader>ca` | Code Actions |
| `<leader>cr` | Rename Symbol |
| `<leader>cf` | Format Document |

---

## 📦 Ferramentas Instaladas

### Language Server
```
✓ Roslyn 5.8.0 - Microsoft C# Language Server
  - Syntax highlighting
  - Autocomplete
  - Go to definition
  - Refactoring
  - Diagnostics
```

### Formatter
```
✓ CSharpier 1.2.6 - Code formatter para C#
  - Format-on-save automático
  - Suporta C# 12 syntax
```

### Debugger
```
✓ netcoredbg 3.1.3 - Debugger para .NET
  - Breakpoints
  - Step debugging
  - Watch variables
  - Call stack
```

### TreeSitter Parsers
```
✓ c_sharp       - C# language
✓ html          - Razor templates
✓ css           - Blazor/Razor styling
✓ javascript    - ASP.NET Core
✓ json          - appsettings.json
✓ yaml          - docker-compose
✓ xml           - .csproj files
```

---

## 🔧 Configuração

### Arquivo Principal
```
~/.config/nvim/lua/plugins/lang/dotnet.lua
```

Contém:
- TreeSitter configuration
- Roslyn LSP settings
- Format-on-save configuration
- Debug adapter setup
- Test runner integration
- EditorConfig support

### Keybindings Customizados
```
~/.config/nvim/lua/config/keymaps.lua
```

### Comandos Customizados
```
~/.config/nvim/lua/config/commands.lua
```

---

## 🧪 Testando a Configuração

### Método 1: Projeto Rápido
```bash
cd /tmp
mkdir my-api && cd my-api
dotnet new webapi -n TestApi -f net8.0
cd TestApi
nvim Program.cs
# Aguarde ~10-15 segundos para LSP iniciar
```

### Método 2: Projeto Existente
```bash
cd seu-projeto-csharp
nvim SeuArquivo.cs
# LSP deve iniciar automaticamente
```

### Verificar LSP
```vim
:LspStatus
```

Deve mostrar:
```
📊 Status do LSP:

Cliente(s) Global(is):
  ✓ roslyn (id: 1)

Cliente(s) para Buffer Atual:
  ✓ roslyn
```

---

## ⚙️ Features Habilitadas

### Inlay Hints
Mostra tipos implícitos e nomes de parâmetros:
```csharp
var result = GetData();  // Mostra tipo retornado
MyMethod(value: 42);     // Mostra nome do parâmetro
```

### Code Lens
Mostra referências e testes acima do código:
```csharp
/// 5 references | 2 tests
public class MyService { ... }
```

### Semantic Highlighting
Syntax highlighting avançado com cores diferentes para:
- Classes
- Interfaces
- Enums
- Methods
- Properties

### Razor Support
Syntax highlighting para `.cshtml`:
```razor
@page "/mypage"
@model MyModel

<h1>@Model.Title</h1>
```

### Format-on-Save
Automático ao salvar com `:w`:
```vim
:w  " Salva e formata automaticamente
```

---

## 🛠️ Problemas Comuns

### LSP não inicia
```bash
# 1. Verificar status
:LspStatus

# 2. Verificar Roslyn
~/.local/share/nvim/mason/bin/roslyn --version

# 3. Verificar .NET 10
~/.dotnet/dotnet --version  # Deve mostrar 10.0+
```

### Build falha
```bash
# Verificar se é projeto .NET
ls *.csproj

# Tentar build manualmente
dotnet build

# Em Neovim
:!dotnet build
```

### Formato incorreto
```bash
# Verificar CSharpier
~/.local/share/nvim/mason/bin/csharpier --version

# Reconfigurar em Neovim
:!~/.local/share/nvim/mason/bin/csharpier SeuArquivo.cs
```

### Autocomplete não funciona
```vim
# Verificar compilação
:!dotnet build

# Recarregar buffer
:e
```

---

## 📚 Recursos para ASP.NET Core

### Estrutura de Projeto Típica
```
MyProject/
├── Program.cs              " Entry point
├── appsettings.json        " Configurações
├── Controllers/            " API endpoints
├── Services/               " Business logic
├── Data/                   " Entity Framework
│   └── AppDbContext.cs
├── Models/                 " Data models
└── Properties/
    └── launchSettings.json
```

### Snippets Disponíveis
Ao digitar em um arquivo .cs, pressione `<C-n>` para autocomplete:
```csharp
controller  " Gera controller class
service     " Gera service class
dbcontext   " Gera DbContext class
model       " Gera model class
```

### Debugging
```vim
# Adicionar breakpoint
:DapToggleBreakpoint  ou  <leader>b

# Iniciar debug
:DapContinue  ou  <F5>

# Step into
:DapStepInto  ou  <F11>

# Step over
:DapStepOver  ou  <F10>
```

---

## 🔗 Integrações Úteis

### EditorConfig
Respeita `.editorconfig` no projeto:
```ini
[*.cs]
indent_style = space
indent_size = 4
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true
```

### LazyVim Extras
Já configurados:
- `lazyvim.plugins.extras.lang.typescript` - JSON support
- `lazyvim.plugins.extras.formatting.prettier` - Formatting
- `lazyvim.plugins.extras.dap.core` - Debugging

---

## 📖 Documentação Oficial

- [Roslyn LSP](https://github.com/dotnet/roslyn/blob/main/docs/wiki/Roslyn-Overview.md)
- [Neovim LSP](https://neovim.io/doc/user/lsp.html)
- [CSharpier](https://csharpier.com/)
- [netcoredbg](https://github.com/Samsung/netcoredbg)

---

## 💡 Dicas Profissionais

1. **Organize imports:**
   ```vim
   :lua vim.lsp.buf.code_action()  " <leader>ca
   ```

2. **Rename refactoring:**
   ```vim
   :lua vim.lsp.buf.rename()  " <leader>cr
   ```

3. **Find all usages:**
   ```vim
   :lua vim.lsp.buf.references()  " <leader>c*
   ```

4. **Hover documentation:**
   ```vim
   K  " Em qualquer símbolo
   ```

5. **Quick fix:**
   ```vim
   <leader>ca  " Code actions
   ```

---

## ✨ Próximas Otimizações (Opcional)

- [ ] Adicionar Entity Framework migrations shortcuts
- [ ] Configurar teste runner visual (neotest)
- [ ] Setup de swagger/OpenAPI inline
- [ ] Docker integration
- [ ] GitHub Actions syntax highlighting

---

## 📝 Changelog

### 2026-05-05
- ✅ .NET 10 Preview instalado
- ✅ Roslyn LSP configurado (v5.8.0)
- ✅ CSharpier formatter habilitado
- ✅ netcoredbg debugger configurado
- ✅ EditorConfig support adicionado
- ✅ ASP.NET Core snippets
- ✅ Razor/Blazor support
- ✅ Keybindings para .NET CLI
- ✅ Comandos customizados (LspStatus, DiagShow, DiagToggle)

---

**Última atualização:** 2026-05-05  
**Versão Neovim:** 0.12.2  
**Status:** Pronto para produção ✨
