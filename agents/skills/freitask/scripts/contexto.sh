#!/bin/bash
# contexto.sh — o que a skill freitask precisa saber antes de abrir uma task,
# impresso de uma vez para entrar no prompt pela injeção `!` do SKILL.md.
#
# Não decide o projeto: quem escolhe é a skill, pelo escopo de cada um, que é
# o primeiro parágrafo depois do H1 do MOC (`projects/<p>/<p>.md`). Daqui saem
# os escopos e duas pistas: a pasta do vault em que a sessão está, e os
# backlogs que o contrato do repo (AGENTS.md, CLAUDE.md, docs/agents/*.md)
# alimenta. É o mesmo elo que o coletor da current-project-state segue no
# sentido contrário (projeto -> repos): contrato que cita o `tasks/` de algum
# projeto alimenta só esses; sem `tasks/` nenhum, vale qualquer citação.
#
# Tudo é derivado do disco (ADR 0017): nenhuma lista de projeto, repo ou host.
# O vault é o de `$HOME`, como no freitask: testar noutro é trocar o HOME.
#
# Uso:
#   contexto.sh [pasta]          a carga da skill (padrão: $PWD)
#   contexto.sh tasks <projeto>  as tasks ativas do projeto: id · fase · título
#
# Só lê. Nunca sai com erro: seção que não deu para levantar diz por quê,
# porque um `!` que falha derruba a skill inteira.

set -uo pipefail

VAULT="$HOME/ObsidianVault"

projetos() {
  local d
  for d in "$VAULT"/projects/*/; do [[ -d "${d}tasks" ]] && basename "$d"; done
}

if [[ "${1:-}" == "tasks" ]]; then
  p=${2:-}
  if [[ -z "$p" ]]; then
    echo "uso: contexto.sh tasks <projeto>"
  elif [[ ! -d "$VAULT/projects/$p/tasks" ]]; then
    echo "projeto '$p' não existe; os do vault: $(projetos | paste -sd' ' -)"
  elif ! command -v freitask >/dev/null; then
    echo "freitask não está no PATH — não dá para listar nem criar task nesta máquina"
  elif ! lista=$(freitask list --json 2>/dev/null); then
    echo "freitask list --json falhou"
  else
    saida=$(printf '%s' "$lista" | jq -r --arg p "$p" \
      '.[] | select(.project == $p) | "- `\(.id)` · \(.status) · \(.title)"')
    echo "${saida:-(nenhuma task ativa em $p)}"
  fi
  exit 0
fi

DIR=${1:-$PWD}

# Projetos citados num conjunto de arquivos, um por linha, sem repetição.
# $1 é o que vem depois de `projects/<p>`: "/tasks" para backlog.
citados() {
  local sufixo=$1 p
  shift
  [[ $# -gt 0 ]] || return 0
  while read -r p; do
    grep -qE "projects/$p$sufixo" "$@" 2>/dev/null && echo "$p"
  done < <(projetos)
}

# O primeiro parágrafo depois do H1, numa linha só.
escopo() {
  local moc="$VAULT/projects/$1/$1.md"
  [[ -f "$moc" ]] || { echo "(sem MOC: escopo desconhecido)"; return; }
  local saida
  saida=$(awk '
    NR == 1 && /^---[[:space:]]*$/ { fm = 1; next }
    fm { if (/^---[[:space:]]*$/) fm = 0; next }
    !h1 { if (/^# /) h1 = 1; next }
    /^[[:space:]]*$/ { if (txt != "") exit; next }
    { sub(/^[[:space:]]+/, ""); txt = txt (txt == "" ? "" : " ") $0 }
    END { print txt }' "$moc")
  echo "${saida:-(MOC sem parágrafo de escopo depois do H1)}"
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
echo "## pistas (ponto de partida, não decisão)"
PISTA=""
case "$DIR/" in
  "$VAULT"/projects/*/*)
    p=${DIR#"$VAULT"/projects/}; p=${p%%/*}
    [[ -d "$VAULT/projects/$p/tasks" ]] && { PISTA=1; echo "projeto: $p (a sessão está na pasta dele no vault)"; }
    ;;
esac
if [[ -n "$REPO" ]]; then
  PISTA=1
  arquivos=()
  for f in "$REPO/AGENTS.md" "$REPO/CLAUDE.md" "$REPO"/docs/agents/*.md; do [[ -f "$f" ]] && arquivos+=("$f"); done
  # Como o coletor: citar um `tasks/` qualquer, mesmo de projeto que não existe
  # mais, já tira o repo do caso "vale qualquer citação".
  if [[ ${#arquivos[@]} -gt 0 ]] && grep -qE "projects/[a-z0-9][a-z0-9_.-]*/tasks" "${arquivos[@]}" 2>/dev/null; then
    mapfile -t ALIMENTA < <(citados "/tasks" "${arquivos[@]}")
  else
    mapfile -t ALIMENTA < <(citados "([/[:space:]\`]|\$)" "${arquivos[@]}")
  fi
  if [[ ${#ALIMENTA[@]} -gt 0 ]]; then
    echo "o contrato deste repo alimenta: ${ALIMENTA[*]}"
  else
    echo "o contrato deste repo não cita projeto nenhum do vault"
  fi
fi
[[ -n "$PISTA" ]] || echo "nenhuma: fora de repositório e fora da pasta de um projeto do vault"

echo
echo "## projetos do vault e o escopo de cada um"
while read -r p; do
  echo "- \`$p\` — $(escopo "$p")"
done < <(projetos)

echo
echo "## tracker do repo"
if [[ -n "$REPO" && -f "$REPO/docs/agents/issue-tracker.md" ]]; then
  echo "$(head -n1 "$REPO/docs/agents/issue-tracker.md" | sed 's/^#* *//') (docs/agents/issue-tracker.md)"
else
  echo "não declarado"
fi

echo
echo "## hoje"
date '+%Y-%m-%d (%d/%m)'
