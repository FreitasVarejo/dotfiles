#!/bin/bash
# contexto.sh — o que a skill freitask precisa saber antes de abrir uma task,
# impresso de uma vez para entrar no prompt pela injeção `!` do SKILL.md.
#
# Tudo é derivado do disco (ADR 0017): nenhuma lista de projeto, repo ou host.
# Projeto é pasta do vault com `tasks/` dentro; um repo pertence a um projeto
# quando o contrato dele (AGENTS.md, CLAUDE.md, docs/agents/*.md) cita
# `projects/<projeto>/`, o mesmo elo que o coletor da current-project-state
# segue no sentido contrário (projeto -> repos).
#
# Só lê. Nunca sai com erro: seção que não deu para levantar diz por quê,
# porque um `!` que falha derruba a skill inteira.

set -uo pipefail

VAULT="$HOME/ObsidianVault"
DIR=${1:-$PWD}

projetos() {
  local d
  for d in "$VAULT"/projects/*/; do [[ -d "${d}tasks" ]] && basename "$d"; done
}

# Projetos citados num conjunto de arquivos, um por linha, sem repetição.
citados() {
  local p
  [[ $# -gt 0 ]] || return 0
  while read -r p; do
    grep -qE "projects/$p([/[:space:]\`]|\$)" "$@" 2>/dev/null && echo "$p"
  done < <(projetos)
}

echo "## onde"
echo "pwd: $DIR"

REPO=""
# Worktree e clone principal são o mesmo repo: o contrato mora no principal.
if comum=$(git -C "$DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
  REPO=$(dirname "$comum")
  topo=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null)
  branch=$(git -C "$DIR" branch --show-current 2>/dev/null)
  echo "repo: $REPO${topo:+$([[ "$topo" != "$REPO" ]] && echo " (worktree em $topo)")}"
  echo "branch: ${branch:-(detached)}"
else
  echo "repo: nenhum (fora de repositório git)"
fi

echo
echo "## projeto"
PROJETO="" ORIGEM="" CANDIDATOS=()
case "$DIR/" in
  "$VAULT"/projects/*/*)
    p=${DIR#"$VAULT"/projects/}; p=${p%%/*}
    [[ -d "$VAULT/projects/$p/tasks" ]] && { PROJETO=$p; ORIGEM="pasta do vault"; }
    ;;
esac
if [[ -z "$PROJETO" && -n "$REPO" ]]; then
  # domain.md é o ponteiro de "onde mora o porquê deste repo": quando ele
  # aponta um projeto só, ele decide, mesmo que outro doc cite uma ADR alheia.
  if [[ -f "$REPO/docs/agents/domain.md" ]]; then
    mapfile -t CANDIDATOS < <(citados "$REPO/docs/agents/domain.md")
    if [[ ${#CANDIDATOS[@]} -eq 1 ]]; then PROJETO=${CANDIDATOS[0]}; ORIGEM="docs/agents/domain.md do repo"; fi
  fi
  if [[ -z "$PROJETO" ]]; then
    arquivos=()
    for f in "$REPO/AGENTS.md" "$REPO/CLAUDE.md" "$REPO"/docs/agents/*.md; do [[ -f "$f" ]] && arquivos+=("$f"); done
    mapfile -t CANDIDATOS < <(citados "${arquivos[@]}")
    if [[ ${#CANDIDATOS[@]} -eq 1 ]]; then PROJETO=${CANDIDATOS[0]}; ORIGEM="contrato do repo"; fi
  fi
fi

if [[ -n "$PROJETO" ]]; then
  echo "projeto: $PROJETO (origem: $ORIGEM)"
elif [[ ${#CANDIDATOS[@]} -gt 1 ]]; then
  echo "projeto: AMBÍGUO — o contrato do repo cita ${CANDIDATOS[*]}"
else
  echo "projeto: NENHUM — esta pasta não é de projeto do vault e o repo não cita projects/<projeto>/ no contrato"
fi
echo "projetos do vault: $(projetos | paste -sd' ' -)"

echo
echo "## tracker do repo"
if [[ -n "$REPO" && -f "$REPO/docs/agents/issue-tracker.md" ]]; then
  echo "$(head -n1 "$REPO/docs/agents/issue-tracker.md" | sed 's/^#* *//') (docs/agents/issue-tracker.md)"
else
  echo "não declarado"
fi

echo
echo "## tasks ativas${PROJETO:+ de $PROJETO}"
if ! command -v freitask >/dev/null; then
  echo "freitask não está no PATH — não dá para criar task nesta máquina"
elif [[ -z "$PROJETO" ]]; then
  echo "(sem projeto resolvido)"
elif ! lista=$(freitask list --json 2>/dev/null); then
  echo "freitask list --json falhou"
else
  saida=$(printf '%s' "$lista" | jq -r --arg p "$PROJETO" \
    '.[] | select(.project == $p) | "- `\(.id)` · \(.status) · \(.title)"')
  echo "${saida:-(nenhuma)}"
fi

echo
echo "## hoje"
date '+%Y-%m-%d (%d/%m)'
