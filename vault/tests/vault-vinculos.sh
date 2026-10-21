#!/bin/bash
# Testes do vault-vinculos num HOME de fixture. O vault, os repos e as notas de
# hosts/ são escritos aqui; o hostname vem do VAULT_HOSTNAME, e o freitask é um
# script falso no PATH, ou falta de propósito.
#
# Uso: vault/tests/vault-vinculos.sh    (sai 0 se tudo passa, 1 se algo falha)

# shellcheck disable=SC2016  # crases literais nos contratos da fixture, não expansão
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VV="$RAIZ/vault/.local/bin/vault-vinculos"
PENDENCIAS="$RAIZ/agents/skills/fechar/scripts/pendencias"

FIX=$(mktemp -d)
FIX=$(cd "$FIX" && pwd -P)
trap 'rm -rf "$FIX"' EXIT

export HOME="$FIX/home"
export VAULT_HOSTNAME=notebook
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
# Pasta da fixture que não é repo não pode subir até um repo de verdade.
export GIT_CEILING_DIRECTORIES="$FIX"

# O PATH sem nenhum freitask, para o caso em que ele falta, e com o falso na
# frente para os outros. O falso responde `projects --json` com o que
# FREITASK_PROJETOS disser e falha com FREITASK_FALHA; cada chamada deixa uma
# linha em $FIX/freitask-chamado.
SEM_FREITASK=""
IFS=: read -ra DIRS <<<"$PATH"
for d in "${DIRS[@]}"; do
  [[ -x "$d/freitask" ]] || SEM_FREITASK+="${SEM_FREITASK:+:}$d"
done
mkdir -p "$FIX/bin"
cat >"$FIX/bin/freitask" <<EOF
#!/bin/bash
echo "\$*" >>"$FIX/freitask-chamado"
[[ "\$*" == "projects --json" && -z "\${FREITASK_FALHA:-}" ]] || exit 1
sep=""
printf '['
for p in \$FREITASK_PROJETOS; do printf '%s{"active":1,"project":"%s"}' "\$sep" "\$p"; sep=","; done
printf ']\n'
EOF
chmod +x "$FIX/bin/freitask"
export PATH="$FIX/bin:$SEM_FREITASK"
export FREITASK_PROJETOS="alfa beta gama"

CASOS=0
FALHAS=0
confere() {
  CASOS=$((CASOS + 1))
  if [[ "$2" == "$3" ]]; then
    printf 'ok    %s\n' "$1"
  else
    FALHAS=$((FALHAS + 1))
    printf 'FALHA %s\n  esperado: %q\n  obtido:   %q\n' "$1" "$2" "$3"
  fi
}

vv() { "$VV" "$@"; }

# escreve <arquivo> <linha>...
escreve() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "${@:2}" >"$1"
}

# repo <dir> [<arquivo> <linha>]...: um repo com um commit, já com o contrato.
novo_repo() {
  local dir=$1
  shift
  git init -q -b main "$dir"
  while [[ $# -ge 2 ]]; do
    escreve "$dir/$1" "$2"
    shift 2
  done
  git -C "$dir" add -A
  git -C "$dir" commit -q --allow-empty -m inicial
}

V="$HOME/ObsidianVault"
D="$HOME/dev"

# --- Fixture -----------------------------------------------------------------
mkdir -p "$V"/projects/{alfa,beta,gama}/tasks "$V/projects/sem-tasks"

novo_repo "$HOME/dotfiles" AGENTS.md 'backlogs: `~/ObsidianVault/projects/gama/tasks/` e projects/alfa/tasks'
novo_repo "$D/so-pasta" docs/agents/domain.md 'o porquê mora em `~/ObsidianVault/projects/beta/`'
novo_repo "$D/com-tasks" AGENTS.md 'issue tracker: projects/alfa/tasks' \
  docs/agents/domain.md 'ADR emprestada: projects/beta/decisoes/0001-x.md'
novo_repo "$D/crase" CLAUDE.md 'o vault: `~/ObsidianVault/projects/gama` e `projects/beta-velho` e projects/sem-tasks/'
novo_repo "$D/tasks-morto" AGENTS.md 'projects/morto/tasks e projects/alfa/'
novo_repo "$D/monorepo" apps/web/AGENTS.md 'projects/alfa/tasks'
novo_repo "$D/principal" AGENTS.md 'projects/alfa/tasks'
git -C "$D/principal" worktree add -q -b wt1 "$D/principal-wt1"
escreve "$D/principal-wt1/AGENTS.md" 'projects/beta/tasks'
git -C "$D/principal-wt1" commit -qam 'muda o backlog na branch'
git -C "$D/principal" worktree add -q -b wt2 "$D/principal-wt2"
git -C "$D/principal" worktree add -q -b wt3 "$D/principal/.claude/worktrees/wt3"
# Worktree de outro nome, que o glob acha antes do principal.
git -C "$D/principal" worktree add -q -b wt4 "$D/aaa-wt"
escreve "$D/nao-git/AGENTS.md" 'projects/alfa/tasks'
escreve "$D/arquivo.txt" 'não é diretório'
novo_repo "$HOME/projects/outro" README.md 'nada'

escreve "$V/hosts/notebook-de-casa.md" '---' 'tags: [host, alfa, "gama"]' '---' '' \
  '# NoteBook — o notebook de casa'
escreve "$V/hosts/servidor.md" '---' 'updated: 2026-10-20' 'tags:' '  - host' '  - beta' \
  '  - beta-velho' 'aliases:' '  - alfa' '---' '' '# srv01 — servidor'
escreve "$V/hosts/servidor.sync-conflict-20261020-121212-ABCDEFG.md" '---' 'tags: [beta]' '---' \
  '' '# srv01 — cópia de conflito'
escreve "$V/hosts/sem-h1.md" '---' 'tags: gama' '---' '' 'Nota sem título.'

linha() {
  local IFS=$'\t'
  printf '%s' "$*"
}

# --- Projetos ----------------------------------------------------------------
confere "projetos: o que o freitask lista" "$(printf 'alfa\nbeta\ngama')" "$(vv projetos)"
confere "projetos: o freitask é quem responde" "$(printf 'alfa\nbeta')" \
  "$(FREITASK_PROJETOS="alfa beta" vv projetos)"
confere "projetos: freitask ausente dá a mesma lista pelo glob" "$(vv projetos)" \
  "$(PATH="$SEM_FREITASK" vv projetos)"
confere "projetos: freitask que falha cai no glob" "$(vv projetos)" "$(FREITASK_FALHA=1 vv projetos)"
confere "projetos: pasta sem tasks/ não é projeto" "" "$(PATH="$SEM_FREITASK" vv projetos | grep -x sem-tasks)"

# --- Repo vinculado ----------------------------------------------------------
confere "repo: contrato cita só projects/b/" "$(linha "$D/so-pasta" beta)" "$(vv repo "$D/so-pasta")"
confere "repo: cita projects/a/tasks e uma ADR de b, só a" "$(linha "$D/com-tasks" alfa)" \
  "$(vv repo "$D/com-tasks")"
confere "repo: crase logo depois do nome encerra a citação" "$(linha "$D/crase" gama)" \
  "$(vv repo "$D/crase")"
confere "repo: tasks/ de projeto que não existe tira o caso da citação solta" \
  "$(linha "$D/tasks-morto" "")" "$(vv repo "$D/tasks-morto")"
confere "repo: monorepo só com contrato aninhado não se vincula" "$(linha "$D/monorepo" "")" \
  "$(vv repo "$D/monorepo")"
confere "repo: lista na ordem dos projetos, sem repetição" "$(linha "$HOME/dotfiles" "alfa gama")" \
  "$(vv repo "$HOME/dotfiles")"
confere "repo: worktree com AGENTS.md editado vale o do clone principal" \
  "$(linha "$D/principal" alfa)" "$(vv repo "$D/principal-wt1")"
confere "repo: worktree em .claude/worktrees/ responde pelo principal" \
  "$(linha "$D/principal" alfa)" "$(vv repo "$D/principal/.claude/worktrees/wt3")"
confere "repo: subpasta responde pela raiz do clone" "$(linha "$D/com-tasks" alfa)" \
  "$(vv repo "$D/com-tasks/docs/agents")"
confere "repo: projeto que o freitask não lista não se vincula" "$(linha "$D/crase" "")" \
  "$(FREITASK_PROJETOS="alfa beta" vv repo "$D/crase")"
confere "repo: fora de git não responde nada" "" "$(vv repo "$D/nao-git")"
vv repo "$FIX/nao-existe" >/dev/null
confere "repo: pasta que não existe sai 0" 0 $?

# --- Repos -------------------------------------------------------------------
confere "repos: todo diretório das raízes, com clone vazio fora de git" "$(
  linha "$HOME/dotfiles" "$HOME/dotfiles" "alfa gama"
  echo
  linha "$D/aaa-wt" "$D/principal" alfa
  echo
  linha "$D/com-tasks" "$D/com-tasks" alfa
  echo
  linha "$D/crase" "$D/crase" gama
  echo
  linha "$D/monorepo" "$D/monorepo" ""
  echo
  linha "$D/nao-git" "" ""
  echo
  linha "$D/principal" "$D/principal" alfa
  echo
  linha "$D/principal-wt1" "$D/principal" alfa
  echo
  linha "$D/principal-wt2" "$D/principal" alfa
  echo
  linha "$D/so-pasta" "$D/so-pasta" beta
  echo
  linha "$D/tasks-morto" "$D/tasks-morto" ""
  echo
  linha "$HOME/projects/outro" "$HOME/projects/outro" ""
)" "$(vv repos)"
# O clone entra na ordem do primeiro diretório dele (o aaa-wt), com a linha do
# próprio principal.
confere "repos <p>: um por clone vinculado, worktrees num repo só" "$(
  linha "$HOME/dotfiles" "$HOME/dotfiles" "alfa gama"
  echo
  linha "$D/principal" "$D/principal" alfa
  echo
  linha "$D/com-tasks" "$D/com-tasks" alfa
)" "$(vv repos alfa)"
confere "repos <p>: projeto sem repo é resposta vazia" "" "$(vv repos nenhum)"
ln -s "$HOME" "$FIX/home-link"
confere "repos <p>: com HOME por symlink, a linha ainda é a do principal" "$FIX/home-link/dev/principal" \
  "$(HOME="$FIX/home-link" vv repos alfa | awk -F'\t' '$2 ~ /\/principal$/ { print $1 }')"

# Dois repos bare na mesma pasta, cada um com um worktree em dev/.
BARE="$FIX/bare"
novo_repo "$FIX/semente" README.md 'semente'
for r in p q; do
  git clone -q --bare "$FIX/semente" "$BARE/bares/$r.git"
  git -C "$BARE/bares/$r.git" worktree add -q "$BARE/dev/$r-main" main
done
confere "repos: repo bare é o próprio clone, e dois na mesma pasta são dois" "$(
  linha "$BARE/dev/p-main" "$BARE/bares/p.git" ""
  echo
  linha "$BARE/dev/q-main" "$BARE/bares/q.git" ""
)" "$(HOME="$BARE" vv repos)"

# O REMOTE da pendencias roda no outro host e fica autocontido de propósito
# (desenho da vault-vinculos, Q5), mas as raízes dele têm que ser estas.
REMOTO_FOR=$(sed -n 's/^for d in \(.*\); do$/\1/p' "$PENDENCIAS" | head -1)
REMOTAS=$(eval "for d in $REMOTO_FOR; do [[ -d \"\$d\" ]] && printf '%s\n' \"\${d%/}\"; done")
confere "repos: as raízes do REMOTE da pendencias são as do módulo" "$(vv repos | cut -f1 | sort)" \
  "$(sort <<<"$REMOTAS")"

# --- Hosts -------------------------------------------------------------------
confere "hosts: nome = basename, ssh = token do H1, tags em linha, em bloco e de valor único" "$(
  linha notebook-de-casa 1 "NoteBook NoteBook-local" "alfa gama" "$V/hosts/notebook-de-casa.md"
  echo
  linha sem-h1 0 "" gama "$V/hosts/sem-h1.md"
  echo
  linha servidor 0 "srv01 srv01-local" beta "$V/hosts/servidor.md"
)" "$(vv hosts)"
confere "esta-maquina: H1 em caixa diferente do hostname é esta máquina" notebook-de-casa \
  "$(vv esta-maquina)"
confere "esta-maquina: pelo token do H1, não pelo basename" servidor \
  "$(VAULT_HOSTNAME=SRV01 vv esta-maquina)"
confere "esta-maquina: máquina sem nota em hosts/ é o hostname" outra-maquina \
  "$(VAULT_HOSTNAME=outra-maquina vv esta-maquina)"
confere "hosts: só o hostname, sem o domínio" 1 \
  "$(VAULT_HOSTNAME=srv01.tailnet.ts.net vv hosts | awk -F'\t' '$1 == "servidor" { print $2 }')"

# --- Vault sem projects/ (o do WSL do trabalho) ------------------------------
WSL="$FIX/wsl"
escreve "$WSL/ObsidianVault/notas.md" 'outro vault'
novo_repo "$WSL/dev/trabalho" AGENTS.md 'projects/alfa/tasks'
rm -f "$FIX/freitask-chamado"
for sub in projetos hosts "repos alfa"; do
  # shellcheck disable=SC2086 # o subcomando leva o argumento junto
  confere "vault sem projects/: '$sub' vazio, saída 0" "rc=0" "$(HOME="$WSL" vv $sub; echo "rc=$?")"
done
confere "vault sem projects/: repo sem projeto" "$(linha "$WSL/dev/trabalho" "")" \
  "$(HOME="$WSL" vv repo "$WSL/dev/trabalho")"
confere "vault sem projects/: o freitask nem é chamado" "" "$(cat "$FIX/freitask-chamado" 2>/dev/null)"

# --- Uso ---------------------------------------------------------------------
for args in "" "desconhecido" "repo" "projetos demais" "repos a b"; do
  # shellcheck disable=SC2086 # cada caso é uma lista de argumentos
  vv $args >/dev/null 2>&1
  confere "uso: '$args' sai 2" 2 $?
done
vv repo "" >/dev/null 2>&1
confere "uso: repo com diretório vazio sai 2" 2 $?
confere "uso: --help mostra as regras" 1 "$(vv --help | grep -c '^- Repo vinculado:')"

printf '\n%d caso(s), %d falha(s)\n' "$CASOS" "$FALHAS"
((FALHAS == 0))
