# Plan: port feature/nvim gaps → main (chore/port-feature-nvim-gaps)

Branch: `chore/port-feature-nvim-gaps` (a partir de `main`)
Working tree inicial: `main` HEAD (já achatado, phase A-F aplicadas).

> Nota: `feature/nvim` neste repo é ancestral de `main` (0 commits à
> frente). Os targets do brief original foram aplicados como polimento
> de `main`, não como cherry-pick.

## Commits

| # | Mensagem | Arquivos |
|---|----------|----------|
| 1 | `chore(nvim): consolidate LazyVim extras and tune lazy bootstrap` | `nvim/lazyvim.json`, `nvim/lua/config/lazy.lua` |
| 2 | `chore(nvim): WSL-friendly options, clean neo-tree keys, inlay-hints toggle` | `nvim/lua/config/options.lua`, `nvim/lua/config/keymaps.lua`, `nvim/init.lua` |
| 3 | `feat(nvim): expand avante, modernize yazi, snacks picker, quiet roslyn` | `nvim/lua/plugins/avante.lua`, `nvim/lua/plugins/ui.lua`, `nvim/lua/plugins/lang/markdown.lua`, `nvim/lua/plugins/lang/dotnet.lua`, `nvim/lua/plugins/treesitter.lua`, `nvim/lua/config/autocmds.lua` |
| 4 | `perf(bash): lazy conda/nvm, fzf fallback, copilot aliases` | `bash/.bashrc`, `bash/.bashrc.d/node-toolchain.sh` |
| 5 | `feat(healthcheck): fd version, nvim warmup, snacks.image optionals` | `healthcheck.sh` |

## O que mudou em cada área

### nvim/lazyvim.json + lazy.lua
- Removidos: `editor.telescope`, `ai.avante`
- Adicionados: `editor.snacks_picker`, `dap.core`, `formatting.prettier`, `lang.typescript`, `lang.tailwind`
- `defaults.lazy = true`, `checker.enabled/notify = false`
- Removidos `import` duplicados em `lazy.lua`

### nvim options/keymaps/init
- `swapfile = false`, `timeoutlen = 500`, `ttimeoutlen = 500`
- `vim.keymap.del` real para `<leader>e`/`<leader>E`
- Removido `<leader>fm` no-op
- Adicionado `<leader>uh` toggle inlay hints (guard Neovim 0.10+)
- `prepend_path` dedup contra `$PATH`
- `NVM_DIR` explícito + sort numérico de versões

### nvim plugins
- **avante.lua**: keymaps `<leader>aa`/`ac`/`ae`/`af`/`ah`/`am`/`ap`/`ar`/`as`/`at` com `behaviour.auto_set_keymaps=false`, `selection.hint_display="none"`, ACP cursor com `args={"acp"}` e `auth="cursor_login"`, blink-cmp-avante opcional
- **ui.lua**: yazi `open_for_directories=true`, `change_neovim_cwd_on_close=true`, comandos `:Yazi`/`:YaziCwd`/`:YaziToggle`, `loaded_netrwPlugin=1`; snacks `picker.enabled=true`; `markdown-preview.nvim` desabilitado
- **lang/markdown.lua**: render-markdown consolidado com `checkbox.enabled=true`
- **lang/dotnet.lua**: roslyn diagnostics `openFiles`, inlay hints reduzidos a 4, code lens off, `lsp_format="prefer"` mantido
- **treesitter.lua**: parsers duplicados removidos
- **autocmds.lua**: virtual text C# = WARN+

### bash
- `.bashrc`: conda lazy (função que carrega no 1º uso), FZF com fallback paths, aliases `??`/`!?`, luacheck portátil
- `node-toolchain.sh`: wrappers `nvm`/`node`/`npm`/`npx`/`pnpm`/`corepack` lazy + `nvm use default` + `corepack enable`

### healthcheck
- fd version check (warn se < 8.4)
- nvim `--headless` smoke (snacks picker warmup, timeout 90s)
- `check_cmd optional` flag para snacks.image (magick, gs, tectonic, mndc)
- `log_warn` vs `log_missing` separados

## Não alterado (preservado de `main`)
- `setup.sh` (phase A)
- `docs/` (docs já em `docs/`)
- `nvim/spell/*.add` (não `.spl`)
- `yazi/flavors/catppuccin-mocha.yazi/` (flavor vendored mantido)
- `tmux/tmux.conf` (allow-passthrough já em phase E)
- `git/config`, `opencode/`

## Validação
- `bash -n bash/.bashrc bash/.bashrc.d/node-toolchain.sh` → OK
- `luac -p` em todos os `.lua` modificados → OK
- `./healthcheck.sh` → ALL_GOOD=true, smoke OK
- `nvim --headless "+checkhealth" +qa` → ver smoke
- `tmux source-file ~/.config/tmux/tmux.conf` → sem "invalid option"
- `readlink ~/.config/nvim/init.lua` → aponta para o repo

## Critérios de aceite do brief
1. Shell startup rápido (conda/nvm lazy) ✓
2. `conda --version` e `node --version` funcionam na primeira chamada ✓
3. fzf bindings mesmo se `fzf --bash` falhar ✓
4. nvim sem E325 de swap ✓
5. Leader Space com `timeoutlen=500` ✓
6. Snacks picker habilitado ✓
7. Yazi via `<leader>-`/`<leader>cw`/`<leader>y`/`:Yazi`/`:YaziToggle` ✓
8. Avante: `<leader>aa`/`<leader>at` etc. com submit `<C-CR>` ✓
9. Copilot extra ativo, Avante não depende do extra `ai.avante` ✓
10. Markdown: checkboxes renderizados; preview browser desabilitado ✓
11. C#: Roslyn `openFiles`, inlay hints via `<leader>uh`, format via LSP ✓
12. `<leader>e`/`<leader>E` do neo-tree removidos ✓
