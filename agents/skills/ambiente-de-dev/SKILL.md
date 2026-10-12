---
name: ambiente-de-dev
description: Contexto do ambiente de desenvolvimento do dono — Neovim (LazyVim), tmux, shell, git e yazi, versionados em ~/dotfiles. Use quando o dono perguntar qual é o atalho de algo, o que uma tecla faz ou como fazer X no nvim ou no tmux dele; quando uma resposta ou um fluxo sugerido depender da config dele (splits, painéis, lazygit, yazi, harpoon, atalhos de LSP); ou antes de mexer nos dotfiles a partir de outro repo.
allowed-tools:
  - Bash(~/.claude/skills/ambiente-de-dev/scripts/consultar *)
metadata:
  surfaces: "code"
---

# Ambiente de dev do dono

A config mora em `~/dotfiles`. O pacote de cada ferramenta e para onde ele vai
estão no `STOW_TARGETS` de `~/dotfiles/setup.sh`; o contrato do repo, em
`~/dotfiles/AGENTS.md`; o porquê, no ponteiro de `~/dotfiles/docs/agents/domain.md`.

## Tecla se pergunta à ferramenta

O arquivo só tem o que o dono mudou. O resto vem do LazyVim, dos extras de
`~/dotfiles/nvim/lazyvim.json` e dos plugins, e o dono apaga e troca padrão.
Não responda de memória do LazyVim: consulte.

```bash
~/.claude/skills/ambiente-de-dev/scripts/consultar nvim harpoon
~/.claude/skills/ambiente-de-dev/scripts/consultar nvim --modo n,x '<leader>p'
~/.claude/skills/ambiente-de-dev/scripts/consultar nvim --tipo cs localleader
~/.claude/skills/ambiente-de-dev/scripts/consultar nvim lsp:
~/.claude/skills/ambiente-de-dev/scripts/consultar tmux split
```

O que é do dono aponta para `~/dotfiles`, na origem ou depois do `←`; no tmux,
leva `*`. A legenda inteira está em `consultar --help`.

## Regras

- Não abra arquivo num Neovim headless para investigar: ao sair, o persistence
  grava a sessão do cwd por cima da do dono. Atalho de buffer sai do
  `consultar nvim --tipo`.
- Alias e função de shell versionados estão em `~/dotfiles/bash/`. Não os liste
  por shell interativo: ele carrega `~/.bashrc.local`, que o deny protege.
- Para mudar a config, leia antes `~/dotfiles/AGENTS.md` e a regra de
  `~/dotfiles/.claude/rules/` cujo `paths:` casa com o arquivo; antes do
  commit, `~/dotfiles/precommit.sh`.
