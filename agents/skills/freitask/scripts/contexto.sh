#!/bin/bash
# contexto.sh — o que a skill freitask precisa saber antes de abrir uma task,
# impresso de uma vez para entrar no prompt pela injeção `!` do SKILL.md.
#
# Não decide o projeto: quem escolhe é a skill, pelo escopo de cada um, que é
# o primeiro parágrafo depois do H1 do MOC (`projects/<p>/<p>.md`). Daqui saem
# os escopos e duas pistas: a pasta do vault em que a sessão está, e os
# projetos que o contrato do repo alimenta. Que projetos existem e o que o
# contrato alimenta vêm do vault-vinculos; a regra está no
# `vault-vinculos --help`.
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
# Perguntados uma vez. Se o vault-vinculos falta ou falha, as seções que
# dependem dele dizem isso.
SEM_VINCULOS="o vault-vinculos não respondeu (o ~/dotfiles/setup.sh o põe no PATH): não sei que projetos existem nem o que o contrato alimenta"
if PROJETOS=$(vault-vinculos projetos 2>/dev/null); then
  SEM_VINCULOS=""
else
  PROJETOS=""
fi

projetos() { [[ -z "$PROJETOS" ]] || printf '%s\n' "$PROJETOS"; }

if [[ "${1:-}" == "tasks" ]]; then
  p=${2:-}
  if [[ -z "$p" ]]; then
    echo "uso: contexto.sh tasks <projeto>"
  elif [[ -z "$SEM_VINCULOS" ]] && ! projetos | grep -xF -- "$p" >/dev/null; then
    echo "projeto '$p' não existe; os do vault: $(projetos | paste -sd' ' -)"
  elif ! command -v freitask >/dev/null; then
    echo "freitask não está no PATH — não dá para listar nem criar task nesta máquina"
  elif ! lista=$(freitask list --json 2>/dev/null); then
    echo "freitask list --json falhou"
  else
    [[ -z "$SEM_VINCULOS" ]] || echo "$SEM_VINCULOS; não conferi se '$p' existe"
    saida=$(printf '%s' "$lista" | jq -r --arg p "$p" \
      '.[] | select(.project == $p) | "- `\(.id)` · \(.status) · \(.title)"')
    echo "${saida:-(nenhuma task ativa em $p)}"
  fi
  exit 0
fi

DIR=${1:-$PWD}

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

# O clone principal e o que o contrato dele alimenta: um worktree responde
# pelo clone. Sem o vault-vinculos, o repo é o worktree mesmo.
REPO=""
ALIMENTA=""
SEM_REPO=$SEM_VINCULOS
if [[ -z "$SEM_REPO" ]]; then
  if linha=$(vault-vinculos repo "$DIR" 2>/dev/null); then
    REPO=$(cut -f1 <<<"$linha")
    ALIMENTA=$(cut -f2 <<<"$linha")
  else
    SEM_REPO="o vault-vinculos não respondeu sobre este repo (o ~/dotfiles/setup.sh o põe no PATH): não sei o clone principal nem o que o contrato alimenta"
  fi
fi
if topo=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null); then
  branch=$(git -C "$DIR" branch --show-current 2>/dev/null)
  echo "repo: ${REPO:-$topo}$([[ -n "$REPO" && "$topo" != "$REPO" ]] && echo " (worktree em $topo)")"
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
    projetos | grep -xF -- "$p" >/dev/null && { PISTA=1; echo "projeto: $p (a sessão está na pasta dele no vault)"; }
    ;;
esac
if [[ -n "$SEM_REPO" ]]; then
  PISTA=1
  echo "$SEM_REPO"
elif [[ -n "$REPO" ]]; then
  PISTA=1
  if [[ -n "$ALIMENTA" ]]; then
    echo "o contrato deste repo alimenta: $ALIMENTA"
  else
    echo "o contrato deste repo não cita projeto nenhum do vault"
  fi
fi
[[ -n "$PISTA" ]] || echo "nenhuma: fora de repositório e fora da pasta de um projeto do vault"

echo
echo "## projetos do vault e o escopo de cada um"
[[ -z "$SEM_VINCULOS" ]] || echo "$SEM_VINCULOS"
while read -r p; do
  echo "- \`$p\` — $(escopo "$p")"
done < <(projetos)


echo
echo "## hoje"
date '+%Y-%m-%d (%d/%m)'
