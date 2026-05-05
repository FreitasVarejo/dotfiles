# 🔧 Troubleshooting - C# / .NET em Neovim

## Problemas Comuns e Soluções

### 1. LSP não inicia / Autocomplete não funciona

**Sintomas:**
```
:LspStatus
  ❌ Nenhum cliente LSP ativo
```

**Soluções:**

a) Verificar se o .NET 10 está instalado:
```bash
~/.dotnet/dotnet --version
# Deve retornar: 10.0.203 ou similar
```

b) Verificar Roslyn:
```bash
~/.local/share/nvim/mason/bin/roslyn --version
# Deve retornar: 5.8.0 ou similar
```

c) Verificar wrapper do Roslyn:
```bash
cat ~/.local/share/nvim/mason/bin/roslyn
# Deve conter: ~/.dotnet/dotnet
```

d) Se o wrapper está errado, corrigir:
```bash
cat > ~/.local/share/nvim/mason/bin/roslyn << 'EOF'
#!/usr/bin/env bash
if [ -f "$HOME/.dotnet/dotnet" ]; then
  exec "$HOME/.dotnet/dotnet" "/home/YOUR_USER/.local/share/nvim/mason/packages/roslyn/libexec/Microsoft.CodeAnalysis.LanguageServer.dll" "$@"
else
  exec dotnet "/home/YOUR_USER/.local/share/nvim/mason/packages/roslyn/libexec/Microsoft.CodeAnalysis.LanguageServer.dll" "$@"
fi
EOF
chmod +x ~/.local/share/nvim/mason/bin/roslyn
```

e) Reiniciar Neovim:
```vim
:e
```

---

### 2. Mensagem "Framework version 10.0.0 not found"

**Causa:** Roslyn está procurando .NET 10 em `/usr/lib64/dotnet/`

**Solução:** O script já foi corrigido no wrapper. Se aparecer novamente:

```bash
# Editar o wrapper
nvim ~/.local/share/nvim/mason/bin/roslyn

# Garantir que use ~/.dotnet/dotnet
# Salvar e testar
~/.local/share/nvim/mason/bin/roslyn --version
```

---

### 3. Build falha em Neovim

**Sintomas:**
```vim
<leader>cs  " Mostra erro de compilação
```

**Soluções:**

a) Verificar se é projeto .NET válido:
```bash
ls *.csproj
# Deve listar pelo menos um arquivo .csproj
```

b) Tentar build manualmente:
```bash
dotnet build
# Se falhar, há erro real no código
```

c) Em Neovim, verificar qual erro:
```vim
:DiagShow
```

d) Se o código está certo, limpar cache:
```bash
dotnet clean
dotnet build
```

---

### 4. Formato não funciona / CSharpier não formata

**Sintomas:**
```vim
:w  " Salva mas não formata
```

**Soluções:**

a) Verificar se CSharpier está instalado:
```bash
~/.local/share/nvim/mason/bin/csharpier --version
# Deve retornar: 1.2.6 ou similar
```

b) Testar CSharpier manualmente:
```bash
~/.local/share/nvim/mason/bin/csharpier SeuArquivo.cs
```

c) Se não funcionar, reinstalar:
```vim
:Mason
# Procurar por "csharpier"
# Desinstalar e reinstalar
```

d) Verificar configuração em:
```bash
cat ~/.config/nvim/lua/plugins/lang/dotnet.lua | grep -A 10 "conform.nvim"
```

e) Forçar formatação manualmente:
```vim
:!~/.local/share/nvim/mason/bin/csharpier %
```

---

### 5. Inlay Hints não aparecem

**Sintomas:**
```csharp
var result = GetData();  // Sem mostrar tipo
```

**Soluções:**

a) Verificar se está habilitado:
```vim
:lua print(vim.inspect(vim.lsp.get_clients()[1].config.settings))
```

b) Procurar por `csharp|inlay_hints`

c) Se não aparecer, adicionar em `dotnet.lua`:
```lua
["csharp|inlay_hints"] = {
  csharp_enable_inlay_hints_for_implicit_variable_types = true,
  csharp_enable_inlay_hints_for_types = true,
  dotnet_enable_inlay_hints_for_parameters = true,
}
```

d) Recarregar:
```vim
:e
```

---

### 6. Autocomplete lento / Com lag

**Soluções:**

a) Verificar se o projeto é grande:
```bash
find . -name "*.cs" | wc -l  # Quantos arquivos?
```

b) Aguardar mais tempo para o LSP analisar:
- Primeira vez: até 30 segundos
- Mudanças grandes: até 15 segundos

c) Desabilitar `fullSolution` analysis se muito lento:
```lua
["csharp|background_analysis"] = {
  dotnet_analyzer_diagnostics_scope = "openFiles",  -- Em vez de "fullSolution"
  dotnet_compiler_diagnostics_scope = "openFiles",
}
```

d) Limpar cache de compilação:
```bash
rm -rf obj bin
dotnet restore
dotnet build
```

---

### 7. Diagnostics mostrando erros falsos

**Sintomas:**
```vim
:DiagShow
# Mostra erros que não existem no código
```

**Soluções:**

a) Isso é normal quando LSP está analisando

b) Aguardar ~30 segundos para análise completa

c) Se persistir, recarregar:
```vim
:e
```

d) Forçar rebuild do LSP:
```bash
dotnet clean
dotnet build
```

e) Em último caso, desabilitar temporariamente:
```vim
:DiagToggle  " Desabilitar diagnósticos
```

---

### 8. "file.cs is not recognized as .cs"

**Soluções:**

```bash
# Definir filetype manualmente
nvim file.cs
:set filetype=cs
```

Ou adicionar ao config:
```lua
vim.filetype.add({
  extension = {
    cs = "cs",
    csproj = "xml",
    cshtml = "cshtml",
  }
})
```

---

### 9. Razor templates não têm syntax highlighting

**Soluções:**

a) Verificar TreeSitter:
```vim
:TSInstall html css  " Instalar parsers necessários
```

b) Verificar se arquivo está marcado como Razor:
```vim
:set filetype=razor
# ou
:set filetype=cshtml
```

c) Adicionar ao config:
```lua
vim.filetype.add({
  extension = {
    cshtml = "html",  -- ou "razor" se tiver parser razor
  }
})
```

---

### 10. Go to Definition não funciona

**Soluções:**

a) Verificar se o LSP está ativo:
```vim
:LspStatus
# Deve mostrar ✓ roslyn
```

b) Colocar cursor sobre um símbolo e testar:
```vim
gd  " Deve abrir definição
```

c) Se não funcionar, tentar:
```vim
:lua vim.lsp.buf.definition()
```

d) Verificar se o símbolo existe:
- Pode estar em arquivo não compilado
- Build o projeto primeiro: `<leader>cs`

---

## ✅ Checklist de Verificação

Quando algo não funciona, executar na ordem:

```bash
# 1. Verificar .NET
~/.dotnet/dotnet --version
ls ~/.dotnet/shared/Microsoft.NETCore.App/

# 2. Verificar Roslyn
~/.local/share/nvim/mason/bin/roslyn --version
cat ~/.local/share/nvim/mason/bin/roslyn

# 3. Verificar projeto .NET
cd seu-projeto
ls *.csproj
dotnet build

# 4. Abrir no Neovim e verificar
nvim Program.cs
:LspStatus
:DiagShow

# 5. Verificar Neovim config
nvim
:lua print(vim.version())
:Lazy
```

---

## 🆘 Quando Nada Funciona

**Opção 1: Limpar tudo e reinstalar**

```bash
# 1. Remover Mason packages
rm -rf ~/.local/share/nvim/mason/packages/roslyn
rm -rf ~/.local/share/nvim/mason/packages/csharpier
rm -rf ~/.local/share/nvim/mason/packages/netcoredbg

# 2. Abrir Neovim
nvim

# 3. Reinstalar
:Mason
# Procurar e instalar: roslyn, csharpier, netcoredbg

# 4. Aguardar instalação
# 5. Reiniciar Neovim
:q
nvim
```

**Opção 2: Verificar logs**

```bash
# Logs do Neovim
:lua vim.lsp.set_log_level("debug")

# Verificar arquivo de log
less ~/.local/share/nvim/lsp.log
```

**Opção 3: Reportar issue**

Se nada funcionar:
1. Coletar informações:
```bash
nvim --version
~/.dotnet/dotnet --version
~/.local/share/nvim/mason/bin/roslyn --version
```

2. Verificar: https://github.com/dotnet/roslyn/issues

---

## 📞 Contato

Para dúvidas sobre a configuração:
- Guia completo: `CSHARP_SETUP.md`
- Início rápido: `CSHARP_QUICK_START.md`
- Documentação Roslyn: https://github.com/dotnet/roslyn

**Status:** Última atualização em 2026-05-05
