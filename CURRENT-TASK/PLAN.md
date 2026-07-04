**Guia de replicação: origin/main -> feature/nvim**

Este documento descreve como um agente LLM poderia replicar todas as mudanças partindo do estado da main remota. A ordem importa: primeiro a refatoração estrutural (senão os paths quebram), depois conteúdo funcional, por fim validação.

**0. Estado inicial e objetivo**

Baseline: branch main com pacotes XDG aninhados em `PACOTE/.config/APP/...` e `setup.sh` que faz stow PACOTE na raiz do repo (espelhando `$HOME`).

Alvo: pacotes achatados na raiz de cada diretório, deploy via `stow -t DESTINO PACOTE`, Neovim com Copilot/Avante/Roslyn corrigido, healthcheck expandido, toolchain Node, Yazi com flavor oficial.

Commits de referência (15, em ordem lógica de implementação):

1. `ca5ff2c` - PATH nvm no init.lua
2. `fbcc6a8` - lazy rocks off + snacks tuning
3. `0a96970` - treesitter parsers + notas mason
4. `ff3c137` - bash node-toolchain
5. `6c406e1` - healthcheck expandido
6. `cfbe480` - yazi catppuccin-mocha
7. `ff9d328` - doc tmux allow-passthrough
8. `a68756e` - AGENTS.md
9. `3188073` - roslyn_ls config
10. `414bd8f` - avante + spell dicts
11. `b47ef9b` - leader keys antes do lazy
12. `a9d83a5` - copilot extras lazyvim
13. `c1c2a85` - formatação via Roslyn LSP
14. `a4abca6` - flatten XDG + setup.sh rewrite
15. merge commit

**1. Pré-requisitos do ambiente**

Antes de editar configs, o agente deve assumir ou instalar:

| Ferramenta                      | Uso                        |
| :------------------------------ | :------------------------- |
| `stow`                          | Deploy dos dotfiles        |
| `shellcheck`                    | Validação dos scripts      |
| `nvim >= 0.9`                   | Editor alvo                |
| `nvm + Node 22`                 | Mason LSP (vtsls, eslint)  |
| `.dotnet + roslyn via Mason`    | LSP C#                     |
| `tree-sitter CLI funcional`     | Mason + checkhealth        |
| `fd >= 8.4`                     | Snacks picker              |
| `ya pkg` (Yazi package manager) | Instalar flavor catppuccin |

<br>

**2. Fase A - Refatoração estrutural (crítica)**

**2.1 Regra geral de movimentação**

Para cada pacote XDG, mover todo o conteúdo de `PACOTE/.config/APP/` para `PACOTE/` e apagar o diretório `.config/` vazio.

| Pacote     | De                            | Para         | Destino stow             |
| :--------- | :---------------------------- | :----------- | :----------------------- |
| `nvim`     | `nvim/.config/nvim/*`         | `nvim/*`     | `$HOME/.config/nvim`     |
| `tmux`     | `tmux/.config/tmux/*`         | `tmux/*`     | `$HOME/.config/tmux`     |
| `git`      | `git/.config/git/*`           | `git/*`      | `$HOME/.config/git`      |
| `yazi`     | `yazi/.config/yazi/*`         | `yazi/*`     | `$HOME/.config/yazi`     |
| `opencode` | `opencode/.config/opencode/*` | `opencode/*` | `$HOME/.config/opencode` |

Comandos equivalentes (exemplo nvim):

```bash
git mv nvim/.config/nvim/* nvim/
git mv nvim/.config/nvim/.* nvim/ 2>/dev/null || true
rmdir nvim/.config/nvim nvim/.config 2>/dev/null || true
```

Repetir para tmux, git, yazi, opencode.

**2.2 Arquivos .stow-local-ignore**

Criar para evitar que docs na raiz do pacote virem symlinks em `~/.config/APP/`:

`tmux/.stow-local-ignore`:

```text
TMUX_CONFIG.md
README.md
```

`opencode/.stow-local-ignore`:

```text
README.md
```

**2.3 Reescrever setup.sh**

Substituir a lógica antiga (`for package in */` + detecção de `.config/`) por:

1. `DOTFILES_DIR` - caminho absoluto do repo via BASH_SOURCE.
2. `declare -A STOW_TARGETS` - mapa pacote -> destino:

   ```bash
   [bash]="$HOME"
   [conda]="$HOME"
   [tmux]="$HOME/.config/tmux"
   [nvim]="$HOME/.config/nvim"
   [git]="$HOME/.config/git"
   [yazi]="$HOME/.config/yazi"
   [opencode]="$HOME/.config/opencode"
   ```

3. `backup_path(target, label)` - se alvo existe e não aponta para `$DOTFILES_DIR`, move para `$HOME/dotfiles_backup_TIMESTAMP/`.
4. `backup_home_package` - itera arquivos em pacotes `$HOME` (bash, conda).
5. `backup_xdg_package` - find recursivo no pacote; ignora `.stow-local-ignore` e `*.md`.
6. Loop: para cada entrada em `STOW_TARGETS`:
   - backup apropriado
   - `mkdir -p` destino XDG
   - `stow -R -t "$local_target" "$pkg_name"` (fallback sem -R)

**2.4 Ajustes pós-flatten**

- `.gitignore`: remover linha `tmux/.config/tmux/plugins/` (path antigo).
- `README.md`: corrigir nome do backup para `dotfiles_backup_...`; adicionar tabela pacote -> destino, `AGENTS.md`; documentar layout achatado e `STOW_TARGETS`.
- `opencode/README.md`: atualizar path para `~/dotfiles/opencode/`.
- `tmux/TMUX_CONFIG.md`: atualizar árvore de diretórios para refletir layout achatado.
- Deletar arquivo acidental `Untitled` (conteúdo era um stub Lua de teste).

**3. Fase B - Neovim**

**3.1 nvim/init.lua - reescrever completamente**

Antes (main): só `require("config.lazy")`.

Depois: definir leaders antes de qualquer plugin; injetar PATH:

```lua
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
-- Bloco do...end que:
-- 1. prepend_path("~/.dotnet") e prepend_path("~/.dotnet/tools")
-- 2. Se ~/.dotnet existe, set DOTNET_ROOT
-- 3. Lê ~/.nvm/alias/default, glob ~/.nvm/versions/node/v{version}*/bin, prepend_path do mais recente
require("config.lazy")
```

Motivo: Neovim inicia sem login shell; `/usr/bin/node v12` quebra Mason LSP.

**3.2 nvim/lua/config/lazy.lua**

Adicionar:

```lua
require("lazy").setup({
  rocks = { enabled = false },
  spec = {
    -- ... existentes ...
    { import = "plugins.lang" }, -- NOVO: import explícito de plugins de linguagem
  },
})
```

**3.3 nvim/lazyvim.json**

Adicionar aos extras:

- `lazyvim.plugins.extras.ai.avante`
- `lazyvim.plugins.extras.ai.copilot`
- `lazyvim.plugins.extras.editor.harpoon2`

**3.4 Novo arquivo nvim/lua/plugins/avante.lua**

Plugin `yetone/avante.nvim` com:

- `provider = "copilot"`, `mode = "agentic"`
- `cursor_applying_provider = "copilot"`
- `mappings.submit.insert = "<C-CR>"` (evita conflito com prefix tmux C-s)
- `acp_providers.cursor` apontando para agent acp em `~/.local/bin/agent` ou `exepath("agent")`
- env vars: `HOME`, `PATH`, `CURSOR_API_KEY`, `CURSOR_AUTH_TOKEN`

**3.5 Novo arquivo nvim/lua/plugins/treesitter.lua**

Lista ensure_installed: css, html, javascript, latex, regex, scss, svelte, tsx, typst, vue.

**3.6 nvim/lua/plugins/ui.lua - snacks.nvim**

Adicionar ao spec de `folke/snacks.nvim`:

```lua
lazy = false,
priority = 1000,
opts = {
  input = { enabled = true },
  image = { enabled = false },
  -- dashboard existente permanece
}
```

**3.7 nvim/lua/plugins/mason.lua**

- Adicionar comentário sobre tree-sitter-cli (cargo ou binário em `~/.local/bin`, não Mason prebuilt).
- Remover "csharpier" de `ensure_installed`.
- Comentário em "roslyn": também faz formatação.

**3.8 nvim/lua/plugins/lang/dotnet.lua - reescrever**

Mudanças principais vs main:

| Aspecto      | Main                      | feature/nvim                                                   |
| :----------- | :------------------------ | :------------------------------------------------------------- |
| Servidor LSP | `roslyn`                  | `roslyn_ls`                                                    |
| opts         | tabela estática           | função `opts = function(_, opts)`                              |
| mason        | implícito                 | `mason = false`                                                |
| filetypes    | `cs`, `csproj`, `cshtml`  | só `cs`                                                        |
| cmd          | `exepath("roslyn")`       | setup custom: `roslyn` ou `roslyn-language-server` + `--stdio` |
| Formatação   | csharpier via conform     | `lsp_format = "prefer"` via Roslyn                             |
| neotest dep  | Issafalcon/neotest-vstest | Nsidorenco/neotest-vstest                                      |

**7.2 yazi/yazi.toml** _(Nota: O material fornecido salta das seções 3.8 até a 7.2)_

Remover bloco:

```toml
[flavor]
use_flavor = true
```

**7.3 Novo yazi/theme.toml**

```toml
[flavor]
dark = "catppuccin-mocha"
```

**7.4 Novo yazi/package.toml**

```toml
[plugin]
deps = []
[[flavor.deps]]
use = "yazi-rs/flavors:catppuccin-mocha"
rev = "0f9204b"
hash = "7dfe41c9c3d9be76da8a844263d0bbed"
```

**7.5 Flavor vendored**

Deletar tema custom antigo:

- `yazi/.config/yazi/flavors/catppuccin.toml`
- `yazi/.config/yazi/theme.toml` (monolítico)

Adicionar diretório completo `yazi/flavors/catppuccin-mocha.yazi/` (flavor oficial: flavor.toml, tmtheme.xml, LICENSE, README.md, preview.png).

Instalação runtime:

```bash
cd ~/dotfiles/yazi && ya pkg install
./setup.sh
```

**8. Fase G - Git e Opencode**

Essencialmente só movimentação (Fase A) + `.stow-local-ignore` no opencode. Conteúdo de config, `opencode.json`, etc. inalterado.

**9. Sequência de validação (obrigatória)**

```bash
shellcheck healthcheck.sh setup.sh      # zero warnings
./setup.sh                              # symlinks corretos
./healthcheck.sh                        # passa (ignora erros gráficos)
tmux source-file ~/.config/tmux/tmux.conf # sem "invalid option"
tree-sitter --version                   # executa
nvim --headless "+checkhealth" +qa      # smoke test rápido
```

Verificar symlinks:

```bash
readlink ~/.config/nvim/init.lua    # -> ~/dotfiles/nvim/init.lua
readlink ~/.config/tmux/tmux.conf   # -> ~/dotfiles/tmux/tmux.conf
readlink ~/.config/yazi/yazi.toml   # -> ~/dotfiles/yazi/yazi.toml
```

Verificar Neovim pós-deploy:

```bash
nvim --headless "+lua print(vim.g.mapleader)" +qa  # deve imprimir espaço
nvim --headless "+Mason" "+qa"                     # roslyn instalado
```

**10. Diagrama de dependências entre fases**

```text
Fase A: Flatten + setup.sh
       |
       v
  .-------------------------------------------------------------------.
  v                v               v               v                  v
Fase B: Neovim   Fase C: Bash    Fase E: Tmux    Fase F: Yazi       Fase G: Git/Opencode
  |
  v
Fase D: Healthcheck
  |
  v
Validação final
```

`ctrl+o to show source`

**11. Armadilhas que o agente não pode ignorar**

1. **Ordem**: editar conteúdo em `nvim/.config/nvim/` _depois_ de mover para `nvim/` - senão duplica ou perde arquivos.
2. **Stow XDG**: sem `-t ~/.config/APP`, symlinks vão para lugar errado.
3. **.stow-local-ignore**: sem ele, README.md do opencode/tmux vira config em runtime.
4. **Spell .spl**: são binários grandes; não tentar gerar via texto - copiar ou `:mkspell`.
5. **Yazi flavor**: `package.toml` + `ya pkg install` + `theme.toml` - os três juntos; só mover arquivos não basta.
6. **Roslyn**: servidor mudou de `roslyn` para `roslyn_ls` no lspconfig; `mason = false` porque Mason registry não mapeia automaticamente.
7. **Leader keys**: devem estar em `init.lua` antes de `require("config.lazy")`, não em `options.lua` (LazyVim sobrescreve tarde demais).
8. **Healthcheck nvim**: primeira execução demora (MasonUpdate); timeout de 300s no wait do registry.

**12. Checklist final para o agente**

- [ ] Todos os pacotes XDG achatados, `.config/` removido
- [ ] `setup.sh` com `STOW_TARGETS` e `stow -t`
- [ ] `init.lua` com leaders + PATH nvm/dotnet
- [ ] `lazy.lua` rocks disabled + import plugins.lang
- [ ] `avante.lua`, `treesitter.lua` criados
- [ ] `dotnet.lua` migrado para roslyn_ls + LSP format
- [ ] `mason.lua` sem csharpier
- [ ] `ui.lua` snacks early load
- [ ] `lazyvim.json` extras ai.avante, ai.copilot, editor.harpoon2
- [ ] Spell en/pt + `.gitignore` ajustado
- [ ] `node-toolchain.sh` + aliases copilot no bashrc
- [ ] `healthcheck.sh` completo
- [ ] Yazi Theme via Flavor oficial
- [ ] Docs atualizados (AGENTS, README, TMUX_CONFIG)
- [ ] `Untitled` e `.mcp-ssh.lock` removidos
- [ ] `./setup.sh` && `./healthcheck.sh` passam
