# Progress - Dotfiles Migration

## Status: EM ANDAMENTO

## Fase A - Refatoracao Estrutural
- [x] Flatten packages (nvim, tmux, git, yazi, opencode)
- [x] .stow-local-ignore files
- [x] setup.sh rewrite
- [x] Ajustes pos-flatten (.gitignore, README, docs)

## Fase B - Neovim
- [x] init.lua: leaders + PATH injection
- [x] lazy.lua: rocks disabled + plugins.lang import
- [x] lazyvim.json: extras avante/copilot/harpoon2
- [x] avante.lua: criado
- [x] treesitter.lua: criado
- [x] ui.lua: snacks early load
- [x] mason.lua: tree-sitter-cli comment + csharpier removido
- [x] dotnet.lua: roslyn_ls + lsp_format = "prefer"

## Fase C - Bash Node Toolchain
- [x] node-toolchain.sh criado
- [x] aliases copilot no bashrc

## Fase D - Healthcheck Expandido
- [x] healthcheck.sh completo

## Fase E - Tmux
- [x] allow-passthrough no tmux.conf
- [x] allow-passthrough docs

## Fase F - Yazi
- [ ] Flavor oficial catppuccin-mocha
- [ ] package.toml + theme.toml
- [ ] Yazi config updated

## Fase G - Git e Opencode
- [ ] .stow-local-ignore opencode

## Validacao Final
- [ ] shellcheck healthcheck.sh setup.sh
- [ ] ./setup.sh
- [ ] ./healthcheck.sh
- [ ] nvim --headless "+checkhealth" +qa