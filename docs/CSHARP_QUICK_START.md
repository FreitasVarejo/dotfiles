# 🚀 Início Rápido - C# 12 no Neovim

## TL;DR - Os Comandos Mais Importantes

```vim
:LspStatus          " Ver status do LSP (Neovim 0.12+)
<leader>cs          " Build projeto
<leader>cr          " Rodar projeto
<leader>ct          " Rodar testes
gd                  " Ir para definição
K                   " Ver documentação
<leader>ca          " Ver sugestões (code actions)
```

---

## ⚡ Começar em 30 Segundos

### 1. Criar Projeto
```bash
dotnet new webapi -n MyApi -f net8.0
cd MyApi
```

### 2. Abrir no Neovim
```bash
nvim Program.cs
```

### 3. Aguardar LSP
Espere 10-15 segundos, depois:
```vim
:LspStatus
```

✅ Pronto! Seu Neovim é uma IDE C# completa!

---

## 🎯 Operações Comuns

### Navegar no Código
| O quê | Como |
|-------|------|
| Ir para definição | `gd` |
| Ver todas referências | `gr` |
| Ver tipo | `gy` |
| Ver implementação | `gI` |

### Editar Código
| O quê | Como |
|-------|------|
| Renomear símbolo | `<leader>cr` |
| Code actions/fix | `<leader>ca` |
| Hover doc | `K` |
| Signature help | `<C-k>` |
| Format | `<leader>fm` ou `:w` (auto) |

### Build & Teste
| O quê | Como |
|-------|------|
| Build | `<leader>cs` |
| Run | `<leader>cr` |
| Test | `<leader>ct` |
| Clean | `<leader>cc` |

---

## 🐛 Diagnosticar Problemas

### Comando 1: Verificar LSP
```vim
:LspStatus
```

Deve mostrar `✓ roslyn` (client rodando)

### Comando 2: Ver Erros
```vim
:DiagShow
```

Mostra todos os erros/warnings do arquivo atual

### Comando 3: Testar Build
```vim
:!dotnet build
```

Se houver erro de compilação, aparece aqui

---

## 💡 Dicas Rápidas

### Problema: LSP não inicia
```bash
# Verificar .NET 10
~/.dotnet/dotnet --version  # Deve ser 10.0+

# Verificar Roslyn
~/.local/share/nvim/mason/bin/roslyn --version
```

### Problema: Autocomplete não funciona
```bash
# Build o projeto primeiro
dotnet build

# Recarregar Neovim
:e
```

### Problema: Formato estranho
```bash
# CSharpier deve estar instalado
~/.local/share/nvim/mason/bin/csharpier --version
```

---

## 📁 Estrutura Recomendada

```
MyProject/
├── Program.cs               # Entry point
├── MyProject.csproj         # Project file
├── appsettings.json         # Configurações
├── .editorconfig            # Formatação
├── Controllers/             # API endpoints
│   └── WeatherController.cs
├── Services/                # Business logic
│   └── MyService.cs
├── Data/                    # Entity Framework
│   └── AppDbContext.cs
└── Models/                  # Data models
    └── User.cs
```

---

## 📦 Ferramentas Instaladas

```
✓ Roslyn LSP 5.8.0         - Language Server
✓ CSharpier 1.2.6          - Formatter
✓ netcoredbg 3.1.3         - Debugger
✓ .NET 10.0.203            - Runtime
```

---

## 🔗 Recursos

- 📖 Guia Completo: `CSHARP_SETUP.md`
- 🐛 Issues: https://github.com/dotnet/roslyn
- 💻 Samples: `/tmp/nvim-csharp-demo/DemoApi`

---

**Status:** ✅ Pronto para usar  
**Última atualização:** 2026-05-05
