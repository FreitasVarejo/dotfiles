# Verificação

Adaptador da skill `verificar` neste repo (ADR 0030 em
`~/ObsidianVault/projects/workflow-ia/decisoes/`). O bloco abaixo é lido pelo
script da skill: globs do que mudou, dois espaços, o comando na raiz do repo.

```portoes
*                                                       ./precommit.sh
agents/**|*/hooks/**|lib/**|setup.sh|healthcheck.sh     ./healthcheck.sh
agents/**                                               python3 -I -m unittest discover -s agents/tests
```

## Como testar à mão

- `nvim/**`: abrir o Neovim e exercitar o que mudou.
- `tmux/**`: `tmux source-file ~/.config/tmux/tmux.conf` e o atalho que mudou.
- `bash/**`: um terminal novo, e o comando ou atalho que mudou.
- `agents/**`: uma sessão nova do Claude Code e `/memory` ou a lista de skills,
  conforme o que mudou; uma trava se testa passando no stdin dela o JSON do
  evento que ela escuta.
- `vault/**`: o comando do `~/.local/bin` que mudou, contra o vault real só em
  modo leitura.
- `cloudflare/**`: numa sessão nova do Claude Code, dentro de um repo,
  `cf zones list` e `cf tunnels list` rodam sem perguntar e não deixam nada no
  `git status`; um `cf-write` pede aprovação.
