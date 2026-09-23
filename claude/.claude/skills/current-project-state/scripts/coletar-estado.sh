#!/bin/bash
# coletar-estado.sh — junta o estado de uma frente de trabalho num digest só.
#
# Lê seis fontes: o backlog do freitask, as notas do projeto no vault, o
# histórico do vaultgit, o git dos repos que carregam contrato apontando para o
# projeto, a esteira do GitHub e o host vinculado.
#
# Escreve em exatamente um lugar, e só com --gravar: o registro da própria
# rodada, em projects/<projeto>/estado-<host>.md. Nunca toca em tasks/.
#
# Nada aqui é lista fixa. Projeto é pasta com `tasks/`; repo pertence ao
# projeto quando o contrato dele cita `projects/<projeto>/`; host se vincula
# pela tag do frontmatter em `hosts/`. O mesmo princípio do `lint_roots()` do
# vault-lint: derivado do disco, porque o clone já mudou de lugar uma vez.
#
# Uso:
#   coletar-estado.sh <projeto> [opções]
#   coletar-estado.sh --listar            # projetos que existem, com apelidos
#
#   --janela <dias>   janela de "o que mudou" (padrão: desde a última coleta
#                     registrada; sem registro, 14 dias)
#   --gravar          grava o registro desta rodada (frontmatter e fila; a
#                     prosa escrita por quem leu é preservada intacta)
#   --json            despeja o documento canônico
#   --sem-rede        pula GitHub e host (offline, ou quando pressa importa)
#   --host <alias>    força o alias de SSH em vez do vinculado pela tag
#
# Fonte que falha nunca derruba o coletor: ela vira uma linha em `## fontes`
# dizendo que não foi lida. "Não vi" e "não há" são respostas diferentes.
#
# Saída: 0 = coletou, 2 = erro de uso ou de ambiente.

set -euo pipefail

VAULT="${FREITASK_VAULT:-$HOME/ObsidianVault}"
JANELA=14
FORMATO=texto
REDE=1
HOST_FORCADO=""
PEDIDO=""
LISTAR=0
GRAVAR=0
JANELA_EXPLICITA=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --listar) LISTAR=1 ;;
    --json) FORMATO=json ;;
    --sem-rede) REDE=0 ;;
    --gravar) GRAVAR=1 ;;
    --janela)
      shift
      [[ ${1:-} =~ ^[0-9]+$ ]] || { echo "coletar-estado: --janela quer um número de dias" >&2; exit 2; }
      JANELA=$1
      JANELA_EXPLICITA=1
      ;;
    --host)
      shift
      HOST_FORCADO=${1:-}
      [[ -n "$HOST_FORCADO" ]] || { echo "coletar-estado: --host quer um alias" >&2; exit 2; }
      ;;
    -h | --help)
      sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "coletar-estado: opção desconhecida: $1" >&2
      exit 2
      ;;
    *)
      [[ -z "$PEDIDO" ]] || { echo "coletar-estado: só um projeto por vez" >&2; exit 2; }
      PEDIDO=$1
      ;;
  esac
  shift
done

command -v jq >/dev/null || { echo "coletar-estado: precisa do jq" >&2; exit 2; }
[[ -d "$VAULT/projects" ]] || { echo "coletar-estado: vault sem projects/ em $VAULT" >&2; exit 2; }

# --- Fontes: o que foi lido e o que não foi --------------------------------
# Num arquivo, e não num array: quase toda coleta roda dentro de `$(...)`, e
# array preenchido em subshell não volta.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FONTES_FILE="$TMP/fontes"
: >"$FONTES_FILE"
fonte() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >>"$FONTES_FILE"; }

# --- Projetos ---------------------------------------------------------------
# A definição é a do AGENTS.md do vault: "o que define um projeto é ter um
# tasks/ dentro". Projeto sem frente aberta não aparece no board nem aqui.
projetos() {
  local d
  for d in "$VAULT"/projects/*/; do
    [[ -d "${d}tasks" ]] || continue
    basename "${d%/}"
  done
}

# Apelidos declarados: o `aliases:` do frontmatter do MOC do projeto, que é
# onde o Obsidian já guarda apelido. Ausente na maioria — daí o fallback.
apelidos() {
  local p=$1 moc="$VAULT/projects/$1/$1.md"
  [[ -f "$moc" ]] || return 0
  awk '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm && /^aliases:/ {
      sub(/^aliases:[[:space:]]*/, "")
      gsub(/[][",]/, " ")
      print
    }
  ' "$moc" | tr ' ' '\n' | grep -v '^$' || true
}

# Projeto vinculado a um host: `hosts/<x>.md` cujo frontmatter `tags:` nomeia
# o projeto. É como o vault já registra "esta máquina é o homelab".
host_do_projeto() {
  local p=$1 h nome
  [[ -d "$VAULT/hosts" ]] || return 0
  for h in "$VAULT"/hosts/*.md; do
    [[ -f "$h" ]] || continue
    nome=$(basename "$h" .md)
    if awk '
      NR == 1 && $0 == "---" { fm = 1; next }
      fm && $0 == "---" { exit }
      fm && /^tags:/ { print }
    ' "$h" | grep -qw "$p"; then
      printf '%s\t%s\n' "$nome" "$h"
      return 0
    fi
  done
  return 0
}

# Prefixo comum entre duas palavras, em caracteres.
prefixo_comum() {
  local a=$1 b=$2 i=0
  while [[ $i -lt ${#a} && $i -lt ${#b} && "${a:$i:1}" == "${b:$i:1}" ]]; do i=$((i + 1)); done
  echo "$i"
}

# Resolve o que o usuário disse para o nome de pasta do vault. Cinco degraus,
# do mais literal ao mais frouxo; qualquer um que devolva mais de um candidato
# não decide — quem decide aí é quem leu a conversa.
resolver() {
  local pedido=$1 p candidatos=() t1 t2 n
  pedido=$(printf '%s' "$pedido" | tr '[:upper:]' '[:lower:]')

  # 1. nome exato da pasta
  while read -r p; do [[ "$p" == "$pedido" ]] && { echo "$p"; return 0; }; done < <(projetos)

  # 2. apelido declarado no `aliases:` do MOC
  while read -r p; do
    if apelidos "$p" | grep -qixF "$pedido"; then echo "$p"; return 0; fi
  done < <(projetos)

  # 3. nome (ou tag) de um host vinculado: "pi01" é o homelab
  while read -r p; do
    while IFS=$'\t' read -r h _; do
      [[ -n "$h" && "$h" == "$pedido" ]] && { echo "$p"; return 0; }
    done < <(host_do_projeto "$p")
  done < <(projetos)

  # 4. um token inteiro em comum: "bjju-vision" e "bjj-vision" compartilham
  #    "vision"; "ai-workflow" e "workflow-ia" compartilham "workflow"
  while read -r p; do
    for t1 in ${p//-/ }; do
      for t2 in ${pedido//-/ }; do
        [[ ${#t1} -ge 3 && "$t1" == "$t2" ]] && { candidatos+=("$p"); break 2; }
      done
    done
  done < <(projetos)
  if [[ ${#candidatos[@]} -eq 1 ]]; then echo "${candidatos[0]}"; return 0; fi

  # 5. prefixo comum de 4+ caracteres, vencedor único: "homeserver" -> "homelab"
  candidatos=()
  while read -r p; do
    n=$(prefixo_comum "$p" "$pedido")
    [[ $n -ge 4 ]] && candidatos+=("$p")
  done < <(projetos)
  if [[ ${#candidatos[@]} -eq 1 ]]; then echo "${candidatos[0]}"; return 0; fi

  return 1
}

if [[ $LISTAR -eq 1 ]]; then
  while read -r p; do
    printf '%-16s %s\n' "$p" "$(apelidos "$p" | paste -sd' ' -)"
  done < <(projetos)
  exit 0
fi

[[ -n "$PEDIDO" ]] || { echo "coletar-estado: falta o projeto (veja --listar)" >&2; exit 2; }

if ! PROJETO=$(resolver "$PEDIDO"); then
  {
    echo "coletar-estado: não sei qual projeto é \"$PEDIDO\". Os que existem:"
    projetos | sed 's/^/  /'
  } >&2
  exit 2
fi

PDIR="$VAULT/projects/$PROJETO"

# O nome desta máquina como o vault a chama: a nota de hosts/ cujo H1 começa
# pelo hostname. `fedora-41` vira `fedora-workstation`; `pi01` é ele mesmo.
# Sem nota correspondente, o hostname serve — o que importa é ser único por
# máquina, porque é isso que torna o conflito de Syncthing impossível.
host_desta_maquina() {
  local hn h nome
  hn=$(hostname -s 2>/dev/null || echo maquina)
  if [[ -d "$VAULT/hosts" ]]; then
    for h in "$VAULT"/hosts/*.md; do
      [[ -f "$h" ]] || continue
      nome=$(basename "$h" .md)
      if grep -qiE "^# *$hn( |$|—|-)" "$h" 2>/dev/null; then
        printf '%s\n' "$nome"
        return 0
      fi
    done
  fi
  printf '%s\n' "$hn"
}
HOST_LOCAL=$(host_desta_maquina)
REGISTRO="$PDIR/estado-$HOST_LOCAL.md"

# --- Registro da rodada anterior --------------------------------------------
# Guarda só o que este coletor não recalcula: quando foi a última coleta, desde
# quando cada pendência está na fila, e o que a conversa decidiu. Lista de task,
# commit e ADR não entram — para isso o coletor é mais rápido e nunca erra.
secao_do_registro() {
  [[ -f "$REGISTRO" ]] || return 0
  awk -v alvo="$1" '
    $0 ~ "^## " alvo "$" { dentro = 1; next }
    dentro && /^## / { exit }
    dentro { print }
  ' "$REGISTRO"
}

COLETADO_EM=""
if [[ -f "$REGISTRO" ]]; then
  COLETADO_EM=$(awk '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm && /^coletado-em:/ { sub(/^coletado-em:[[:space:]]*/, ""); print; exit }
  ' "$REGISTRO")
fi

if [[ $JANELA_EXPLICITA -eq 1 ]]; then
  DESDE=$(date -d "-$JANELA days" +%Y-%m-%d)
  JANELA_ORIGEM="--janela $JANELA dias"
elif [[ -n "$COLETADO_EM" ]]; then
  DESDE=${COLETADO_EM:0:10}
  # Quanto tempo faz, em palavra: "desde 2026-09-23" sozinho parece defeito
  # quando a coleta foi hoje de manhã.
  _seg=$(( $(date +%s) - $(date -d "$COLETADO_EM" +%s 2>/dev/null || date +%s) ))
  if [[ $_seg -lt 5400 ]]; then _faz="há $(( _seg / 60 )) min"
  elif [[ $_seg -lt 172800 ]]; then _faz="há $(( _seg / 3600 ))h"
  else _faz="há $(( _seg / 86400 )) dias"; fi
  JANELA_ORIGEM="desde a última coleta, $_faz (${COLETADO_EM:0:16})"
else
  DESDE=$(date -d "-$JANELA days" +%Y-%m-%d)
  JANELA_ORIGEM="$JANELA dias (não há registro anterior)"
fi

# --- Tasks ------------------------------------------------------------------
# O freitask é a autoridade do que existe e em que fase está; ele não devolve
# título nem descrição, então cada arquivo é lido para pegar o que importa:
# a linha em itálico (o melhor resumo de uma linha que este vault tem), o
# motivo do bloqueio e o `dono`/`desde`/`dominio`, que é como se vê se tem
# agente segurando a task.
parse_task() {
  awk '
    function limpar(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    NR == 1 && $0 == "---" { fm = 1; next }
    fm {
      if ($0 == "---") { fm = 0; next }
      if ($0 ~ /^dono:/)    { sub(/^dono:/, "");    dono = limpar($0) }
      if ($0 ~ /^desde:/)   { sub(/^desde:/, "");   desde = limpar($0) }
      if ($0 ~ /^dominio:/) { sub(/^dominio:/, ""); dominio = limpar($0) }
      next
    }
    !titulo && /^> \[!/ {
      linha = $0
      match(linha, /\[![a-z]+\]/)
      callout = substr(linha, RSTART + 2, RLENGTH - 3)
      titulo = limpar(substr(linha, RSTART + RLENGTH))
      bloco = 1
      next
    }
    bloco && /^>/ {
      corpo = limpar(substr($0, 2))
      if (corpo ~ /^\[\[/) next                       # o wikilink da linha 2
      if (!estado && corpo ~ /^_.*_$/) {              # o itálico é o estado
        estado = substr(corpo, 2, length(corpo) - 2)
        next
      }
      if (corpo != "") notas = notas (notas ? " " : "") corpo
      next
    }
    bloco && !/^>/ { bloco = 0 }
    /^## Hist/ { hist = 1; next }
    hist && /^- [0-9]{4}-[0-9]{2}-[0-9]{2}/ { data = substr($0, 3, 10) }
    END {
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
        callout, titulo, estado, notas, dono, desde, dominio, data
    }
  ' "$1"
}

FASES_JSON=$(cat "$VAULT/.freitask/status.json" 2>/dev/null || echo '{}')

tasks_json() {
  local id path arquivada status
  if ! command -v freitask >/dev/null; then
    fonte freitask ausente "freitask não está no PATH — backlog não lido"
    echo '[]'
    return 0
  fi
  local bruto
  if ! bruto=$(freitask list --json --archived 2>/dev/null); then
    fonte freitask erro "freitask list --json falhou — backlog não lido"
    echo '[]'
    return 0
  fi
  fonte freitask ok "freitask list --json --archived"

  # O campo vazio no meio vira '-': TAB é IFS-whitespace e `read` colapsa dois
  # seguidos, jogando o campo seguinte na variável errada.
  while IFS=$'\t' read -r id path arquivada status; do
    [[ -n "$id" ]] || continue
    [[ -f "$path" ]] || continue
    [[ "$arquivada" == "-" ]] && arquivada=""
    local campos
    campos=$(parse_task "$path")
    printf '%s\t%s\t%s\t%s\n' "$id" "$arquivada" "$status" "$campos"
  done < <(
    printf '%s' "$bruto" | jq -r --arg p "$PROJETO" '
      .[] | select(.project == $p)
      | [.id, .path, (.archived // "-"), .status] | @tsv'
  ) | jq -R -s --argjson fases "$FASES_JSON" '
      split("\n") | map(select(length > 0)) | map(split("\t")) | map({
        id: .[0], arquivada: .[1], fase: .[2],
        callout: .[3], titulo: .[4], estado: .[5], notas: .[6],
        dono: .[7], desde: .[8], dominio: .[9], data: .[10]
      })
      | map(. as $t | . + { ordem: (
          ($fases | to_entries
            | map(select(.value.callout == $t.callout or .value.title == $t.fase))
            | .[0].key // "9") | tonumber? // 9
        ) })
    '
}

# --- Mudanças no vault ------------------------------------------------------
# O vaultgit é um log de undo local: checkpoint a cada 15 min. Serve como
# timeline do refinamento — ADR que nasceu, spec que mudou, task arquivada.
vault_json() {
  if ! command -v vaultgit >/dev/null; then
    fonte vaultgit ausente "vaultgit não está no PATH — timeline do vault não lida"
    echo '[]'
    return 0
  fi
  local bruto
  if ! bruto=$(vaultgit log --since="$DESDE" --name-status --date=short \
        --pretty=format:'C%x09%h%x09%ad' -- "projects/$PROJETO" 2>/dev/null); then
    fonte vaultgit erro "vaultgit log falhou — timeline do vault não lida"
    echo '[]'
    return 0
  fi
  fonte vaultgit ok "checkpoints desde $DESDE"
  printf '%s\n' "$bruto" | awk -F'\t' '
    $1 == "C" { sha = $2; data = $3; next }
    NF >= 2 && $1 ~ /^[AMDR]/ {
      arquivo = $NF
      genero = "outro"
      # O registro que esta própria skill escreve sai da timeline: senão toda
      # rodada reporta como novidade o arquivo que ela acabou de gravar.
      if (arquivo ~ /\/estado-[^\/]+\.md$/)   next
      if (arquivo ~ /\/decisoes\//)        genero = "adr"
      else if (arquivo ~ /\/tasks\//)      genero = "task"
      else if (arquivo ~ /\/reviews\//)    genero = "review"
      else if (arquivo ~ /\.md$/)          genero = "spec"
      printf "%s\t%s\t%s\t%s\t%s\n", data, genero, substr($1, 1, 1), arquivo, sha
    }
  ' | sort -t$'\t' -k4,4 -k1,1r | awk -F'\t' '!visto[$4]++' | sort -t$'\t' -k1,1r | jq -R -s '
      split("\n") | map(select(length > 0)) | map(split("\t")) | map({
        data: .[0], genero: .[1], acao: .[2], arquivo: .[3], commit: .[4]
      })'
}

# --- Repos ------------------------------------------------------------------
# Um repo pertence ao projeto quando o contrato dele aponta para a pasta do
# projeto no vault — que é o elo que a ADR 0001 já mandou existir ("o repo
# carrega contrato, o vault carrega o porquê"). Nenhuma lista fixa.
contrato_cita() {
  local dir=$1 arquivos=()
  local f
  for f in "$dir/AGENTS.md" "$dir/CLAUDE.md"; do [[ -f "$f" ]] && arquivos+=("$f"); done
  if [[ -d "$dir/docs/agents" ]]; then
    while IFS= read -r f; do arquivos+=("$f"); done \
      < <(find "$dir/docs/agents" -maxdepth 1 -name '*.md' -type f 2>/dev/null)
  fi
  [[ ${#arquivos[@]} -gt 0 ]] || return 1
  grep -qlE "projects/$PROJETO([/[:space:]]|\$)" "${arquivos[@]}" 2>/dev/null
}

# Worktree e repo principal são o MESMO repo. Sem isto, os sete worktrees do
# mesmo clone apareceriam como sete frentes de trabalho.
raiz_do_repo() {
  local dir=$1 comum
  comum=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
  dirname "$comum"
}

slug_github() {
  git -C "$1" remote get-url origin 2>/dev/null |
    sed -nE 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##; /^[^/]+\/[^/]+$/p'
}

repos_do_projeto() {
  local parent dir raiz
  for parent in "$HOME/dotfiles" "$HOME"/dev/*/ "$HOME"/projects/*/; do
    dir=${parent%/}
    [[ -d "$dir" ]] || continue
    contrato_cita "$dir" || continue
    raiz=$(raiz_do_repo "$dir") || continue
    printf '%s\n' "$raiz"
  done | sort -u
}

repos_json() {
  # A contagem sai ANTES do pipe: `n` incrementado dentro de um `while` que é
  # o começo de um pipeline morre com o subshell.
  local raiz n
  n=$(repos_do_projeto | grep -c . || true)
  if [[ $n -eq 0 ]]; then
    fonte repos vazio "nenhum repo com contrato apontando para projects/$PROJETO"
  else
    fonte repos ok "$n repo(s) — worktrees deduplicados pelo git-common-dir"
  fi
  while read -r raiz; do
    [[ -n "$raiz" ]] || continue
    local branch sujo upstream ahead behind slug
    branch=$(git -C "$raiz" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')
    sujo=$(git -C "$raiz" status --porcelain 2>/dev/null | wc -l)
    slug=$(slug_github "$raiz")
    ahead=0; behind=0
    if upstream=$(git -C "$raiz" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null); then
      read -r behind ahead < <(git -C "$raiz" rev-list --left-right --count "$upstream...HEAD" 2>/dev/null || echo "0 0")
    else
      upstream=""
    fi
    jq -n \
      --arg path "$raiz" --arg branch "$branch" --arg slug "$slug" \
      --arg upstream "$upstream" --argjson sujo "$sujo" \
      --argjson ahead "${ahead:-0}" --argjson behind "${behind:-0}" \
      --argjson worktrees "$(
        git -C "$raiz" worktree list --porcelain 2>/dev/null |
          awk '/^worktree /{p=substr($0,10)} /^branch /{b=substr($0,8); sub(/^refs\/heads\//,"",b); print p "\t" b} /^detached/{print p "\t(detached)"}' |
          jq -R -s 'split("\n")|map(select(length>0))|map(split("\t"))|map({path:.[0],branch:.[1]})'
      )" \
      --argjson sem_upstream "$(
        git -C "$raiz" for-each-ref --format='%(refname:short) %(upstream)' refs/heads 2>/dev/null |
          awk 'NF==1{print $1}' | jq -R -s 'split("\n")|map(select(length>0))'
      )" \
      --argjson commits "$(
        git -C "$raiz" log --all --no-merges --since="$DESDE" --date=short \
          --pretty=format:'%h%x09%cd%x09%an%x09%s' 2>/dev/null | awk 'NR <= 30' |
          jq -R -s 'split("\n")|map(select(length>0))|map(split("\t"))|map({sha:.[0],data:.[1],autor:.[2],assunto:.[3]})'
      )" \
      '{path:$path, branch:$branch, github:$slug, upstream:$upstream, sujo:$sujo,
        ahead:$ahead, behind:$behind, worktrees:$worktrees,
        sem_upstream:$sem_upstream, commits:$commits}'
  done < <(repos_do_projeto) | jq -s '.'
}

# --- Planos de sessão -------------------------------------------------------
# Ponteiro, não fonte: o que sobreviveu virou task, ADR ou commit. Serve para
# lembrar o que foi pensado e ainda não virou nada disso.
planos_json() {
  local dir="$HOME/.claude/plans" f
  if [[ ! -d "$dir" ]]; then
    fonte planos ausente "$dir não existe"
    echo '[]'
    return 0
  fi
  fonte planos ok "3 mais recentes que citam o projeto"
  local termos="$PROJETO"
  while read -r r; do [[ -n "$r" ]] && termos="$termos|$(basename "$r")"; done < <(repos_do_projeto)
  while IFS= read -r f; do
    grep -qiE "$termos" "$f" 2>/dev/null || continue
    printf '%s\t%s\t%s\n' \
      "$f" "$(date -r "$f" +%Y-%m-%d)" \
      "$(grep -m1 '^# ' "$f" 2>/dev/null | sed 's/^# //')"
  done < <(find "$dir" -maxdepth 1 -name '*.md' -type f -printf '%T@ %p\n' 2>/dev/null |
           sort -rn | cut -d' ' -f2-) | awk 'NR <= 3' |
    jq -R -s 'split("\n")|map(select(length>0))|map(split("\t"))|map({arquivo:.[0],data:.[1],titulo:.[2]})'
}

# --- Esperando você ---------------------------------------------------------
# A seção que responde "o que depende de mim". Quatro procedências: a esteira
# do GitHub, as notas avulsas do painel, as pendências declaradas nas specs e
# (montadas na renderização) as tasks em homologação.
gh_json() {
  local o='{"prs":[],"issues":[]}'
  if [[ $REDE -eq 0 ]]; then
    fonte github pulado "--sem-rede"
    echo "$o"; return 0
  fi
  if ! command -v gh >/dev/null; then
    fonte github ausente "gh não está no PATH"
    echo "$o"; return 0
  fi
  local slug prs='[]' issues='[]' algum=0
  while read -r raiz; do
    [[ -n "$raiz" ]] || continue
    slug=$(slug_github "$raiz") || true
    [[ -n "$slug" ]] || continue
    algum=1
    local p i
    p=$(timeout 25 gh pr list --repo "$slug" --state open --limit 30 \
          --json number,title,headRefName,updatedAt,isDraft,reviewDecision,author 2>/dev/null) || p='[]'
    i=$(timeout 25 gh issue list --repo "$slug" --state open --limit 60 \
          --json number,title,labels,updatedAt 2>/dev/null) || i='[]'
    prs=$(jq -s --arg r "$slug" 'add // [] | map(. + {repo: $r})' <(echo "$prs") <(echo "$p" | jq --arg r "$slug" 'map(. + {repo:$r})'))
    # Label que pede humano: derivada por padrão no nome, não por lista fixa.
    issues=$(jq -s 'add // []' <(echo "$issues") <(
      echo "$i" | jq --arg r "$slug" '
        map(. + {repo: $r, labels: [.labels[].name]})
        | map(select(.labels | any(test("human|revis|homolog|aprova"; "i"))))'))
  done < <(repos_do_projeto)
  if [[ $algum -eq 0 ]]; then
    fonte github vazio "nenhum repo do projeto tem remote no GitHub"
  else
    fonte github ok "PRs abertos e issues com label pedindo humano"
  fi
  jq -n --argjson prs "$prs" --argjson issues "$issues" '{prs:$prs, issues:$issues}'
}

notas_avulsas_json() {
  local painel="$VAULT/CURRENT.md"
  if [[ ! -f "$painel" ]]; then
    fonte painel ausente "$painel não existe"
    echo '[]'; return 0
  fi
  fonte painel ok "## Notas Avulsas do CURRENT.md"
  local termos="$PROJETO"
  while read -r r; do [[ -n "$r" ]] && termos="$termos|$(basename "$r")"; done < <(repos_do_projeto)
  awk '
    /^## Notas Avulsas/ { dentro = 1; next }
    dentro && /^## / { exit }
    dentro {
      if (/^- /) { if (b != "") print b; b = substr($0, 3) }
      else if (b != "" && /^[[:space:]]+[^[:space:]]/) { sub(/^[[:space:]]+/, " "); b = b $0 }
      else if (b != "" && /^$/) { print b; b = "" }
    }
    END { if (b != "") print b }
  ' "$painel" | { grep -iE "$termos" || true; } |
    jq -R -s 'split("\n")|map(select(length>0))'
}

pendencias_json() {
  [[ -d "$PDIR" ]] || { echo '[]'; return 0; }
  { grep -rlE '^## Pend' "$PDIR" --include='*.md' 2>/dev/null || true; } |
    { grep -v '/tasks/' || true; } | sed "s|^$VAULT/||" | sort |
    jq -R -s 'split("\n")|map(select(length>0))'
}

# --- Host --------------------------------------------------------------------
# Para frente cuja realidade não está em repo nenhum: o que está no ar é o
# estado. Read-only (docker ps), BatchMode (nunca pede senha) e timeout curto.
host_json() {
  local alias="" nota=""
  if [[ -n "$HOST_FORCADO" ]]; then
    alias=$HOST_FORCADO
  else
    IFS=$'\t' read -r alias nota < <(host_do_projeto "$PROJETO")
  fi
  if [[ -z "$alias" ]]; then
    echo 'null'; return 0
  fi
  if [[ $REDE -eq 0 ]]; then
    fonte host pulado "--sem-rede (vínculo: $alias)"
    jq -n --arg a "$alias" --arg n "${nota:-}" '{alias:$a, nota:$n, estado:"não consultado", containers:[]}'
    return 0
  fi
  local saida="" usado=""
  local tentativa
  for tentativa in "$alias" "$alias-local"; do
    if saida=$(timeout 25 ssh -o BatchMode=yes -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=accept-new "$tentativa" \
        'docker ps -a --format "{{.Names}}\t{{.Status}}"' 2>/dev/null); then
      usado=$tentativa
      break
    fi
    saida=""
  done
  if [[ -z "$usado" ]]; then
    fonte host inacessivel "$alias e $alias-local não responderam"
    jq -n --arg a "$alias" --arg n "${nota:-}" '{alias:$a, nota:$n, estado:"inacessível", containers:[]}'
    return 0
  fi
  fonte host ok "docker ps -a via $usado"
  jq -n --arg a "$usado" --arg n "${nota:-}" --argjson c "$(
    printf '%s\n' "$saida" | jq -R -s 'split("\n")|map(select(length>0))|map(split("\t"))|map({nome:.[0],status:.[1]})'
  )" '{alias:$a, nota:$n, estado:"ok", containers:$c}'
}

# --- Avisos ------------------------------------------------------------------
# Resumo dos dois vigias. Nunca fatais aqui: vault-lint já é aviso por decisão
# (ADR 0009) e o doctor tem dono próprio — este coletor só repassa.
avisos_json() {
  local doctor="-" lint="-"
  if command -v freitask >/dev/null; then
    timeout 30 freitask doctor --quiet >/dev/null 2>&1 && doctor="limpo" || doctor="tem achado (rode: freitask doctor)"
  fi
  if command -v vault-lint >/dev/null; then
    timeout 30 vault-lint --quiet >/dev/null 2>&1 && lint="limpo" || lint="tem achado (rode: vault-lint)"
  fi
  jq -n --arg d "$doctor" --arg l "$lint" '{doctor:$d, vault_lint:$l}'
}

# --- Montagem ---------------------------------------------------------------
TASKS=$(tasks_json)
VAULTLOG=$(vault_json)
REPOS=$(repos_json)
PLANOS=$(planos_json)
GH=$(gh_json)
NOTAS=$(notas_avulsas_json)
PENDENCIAS=$(pendencias_json)
HOST=$(host_json)
AVISOS=$(avisos_json)

REGISTRO_JSON=$(
  if [[ -f "$REGISTRO" ]]; then
    fonte registro ok "${REGISTRO#"$VAULT"/}"
  else
    fonte registro vazio "primeira rodada nesta máquina — ${REGISTRO#"$VAULT"/} ainda não existe"
  fi
  jq -n \
    --argjson existe "$([[ -f "$REGISTRO" ]] && echo true || echo false)" \
    --arg caminho "${REGISTRO#"$VAULT"/}" \
    --arg coletado "$COLETADO_EM" \
    --argjson fila "$(
      secao_do_registro "Na sua fila desde" |
        sed -n 's/^- \(.*\) — visto desde \([0-9-]\{10\}\) · \([0-9]*\).*$/\1\t\2\t\3/p' |
        jq -R -s 'split("\n")|map(select(length>0))|map(split("\t"))|map({chave:.[0],desde:.[1],rodadas:(.[2]|tonumber? // 1)})'
    )" \
    --arg decidido "$(secao_do_registro "Decidido na conversa")" \
    --arg adiado "$(secao_do_registro "Adiado de propósito")" \
    --arg leitura "$(secao_do_registro "Leitura da última rodada")" \
    '{existe:$existe, caminho:$caminho, coletado_em:$coletado, fila:$fila,
      decidido:$decidido, adiado:$adiado, leitura:$leitura}'
)

MOC="-"
[[ -f "$PDIR/$PROJETO.md" ]] && MOC="projects/$PROJETO/$PROJETO.md"
# find sai 1 quando decisoes/ não existe (projeto sem ADR nenhuma): com
# pipefail isso derrubaria a montagem inteira.
ADRS=$({ find "$PDIR/decisoes" -maxdepth 1 -name '*.md' -type f 2>/dev/null || true; } | wc -l)
fonte vault ok "$PDIR"

DOC=$(jq -n \
  --arg projeto "$PROJETO" --arg pedido "$PEDIDO" \
  --arg gerado "$(date '+%Y-%m-%d %H:%M')" --arg desde "$DESDE" \
  --argjson janela "$JANELA" --arg moc "$MOC" --argjson adrs "$ADRS" \
  --argjson fontes "$(jq -R -s 'split("\n")|map(select(length>0))|map(split("\t"))|map({fonte:.[0],estado:.[1],detalhe:.[2]})' <"$FONTES_FILE")" \
  --argjson tasks "$TASKS" --argjson vault "$VAULTLOG" --argjson repos "$REPOS" \
  --argjson planos "$PLANOS" --argjson gh "$GH" --argjson notas "$NOTAS" \
  --argjson pendencias "$PENDENCIAS" --argjson host "$HOST" --argjson avisos "$AVISOS" \
  --argjson registro "$REGISTRO_JSON" --arg janela_origem "$JANELA_ORIGEM" \
  '{projeto:$projeto, pedido:$pedido, gerado_em:$gerado, janela_dias:$janela,
    desde:$desde, moc:$moc, adrs:$adrs, fontes:$fontes, tasks:$tasks,
    mudancas_vault:$vault, repos:$repos, planos:$planos,
    esperando: ($gh + {notas_avulsas:$notas, pendencias:$pendencias}),
    host:$host, avisos:$avisos, registro:$registro,
    janela_origem:$janela_origem}')

# --- Gravação do registro ---------------------------------------------------
# O único caminho de escrita deste script. Dono do frontmatter e da fila; a
# prosa das três seções seguintes é de quem leu o relatório e volta intacta.
gravar_registro() {
  local hoje agora fila dec adi lei tmp
  hoje=$(date +%Y-%m-%d)
  agora=$(date --iso-8601=seconds)

  # Item que já estava mantém a data de entrada e ganha uma rodada; item novo
  # entra com hoje. Item que saiu da pendência some — MAS só se a fonte dele
  # foi lida de verdade: com --sem-rede, PR e issue ficam como estavam, senão
  # a primeira rodada offline apagaria o histórico inteiro.
  fila=$(printf '%s' "$DOC" | jq -r --arg hoje "$hoje" '
    . as $r
    | ( [ $r.esperando.prs[]    | "PR #\(.number)" ]
      + [ $r.esperando.issues[] | "issue #\(.number)" ]
      + [ $r.tasks[] | select(.arquivada == "" and .callout == "question") | "task `\(.id)`" ]
      ) as $agora
    | ( $r.registro.fila | map({key: .chave, value: .}) | from_entries ) as $antes
    | ( [ $r.fontes[] | select(.fonte == "github"   and .estado == "ok") ] | length > 0 ) as $gh_ok
    | ( [ $r.fontes[] | select(.fonte == "freitask" and .estado == "ok") ] | length > 0 ) as $ft_ok
    | ( $agora | map( . as $k | {
          chave: $k,
          desde: ($antes[$k].desde // $hoje),
          rodadas: (($antes[$k].rodadas // 0) + 1)
        }) ) as $novos
    | ( $r.registro.fila
        | map(select([.chave] | inside($agora) | not))
        | map(select(if (.chave | startswith("task")) then ($ft_ok | not) else ($gh_ok | not) end))
      ) as $preservados
    | ($novos + $preservados) | sort_by(.desde)
    | .[] | "- \(.chave) — visto desde \(.desde) · \(.rodadas) rodada\(if .rodadas == 1 then "" else "s" end)"')

  dec=$(secao_do_registro "Decidido na conversa")
  adi=$(secao_do_registro "Adiado de propósito")
  lei=$(secao_do_registro "Leitura da última rodada")

  # Temporário na MESMA pasta: `mv` só é atômico dentro do mesmo sistema de
  # arquivos, e escrita pela metade num vault sincronizado é o que não pode.
  tmp=$(mktemp "$PDIR/.estado-XXXXXX")
  {
    printf -- '---\n'
    printf 'tipo: registro\nstatus: vigente\n'
    printf 'data: %s\nhost: %s\ncoletado-em: %s\n' "$hoje" "$HOST_LOCAL" "$agora"
    printf 'origem: "skill current-project-state"\n'
    printf -- '---\n\n'
    printf '# Estado de %s — registro da skill\n\n' "$PROJETO"
    cat <<'TXT'
**Isto não é spec, e não é cópia do backlog.** Task, commit, ADR e PR vivem no
coletor, que os recalcula em segundos; aqui fica só o que ele não sabe derivar.
Quando este registro divergir do coletor, quem está errado é ele.

Task é citada entre crases, nunca como wikilink com caminho: arquivar uma task
muda o caminho dela, e o link quebrado vira erro irreparável no `freitask doctor`.
TXT
    printf '\n## Na sua fila desde\n'
    printf '<!-- gerado pelo coletor: não edite à mão. A data é quando ESTE registro\n'
    printf '     passou a ver o item, não quando ele nasceu; a idade real do item vem\n'
    printf '     da linha atualizado que o coletor traz viva. -->\n'
    if [[ -n "$fila" ]]; then printf '%s\n' "$fila"; else printf -- '- nada esperando você\n'; fi
    printf '\n## Decidido na conversa\n'
    [[ -n "$dec" ]] && printf '%s\n' "$dec"
    printf '\n## Adiado de propósito\n'
    [[ -n "$adi" ]] && printf '%s\n' "$adi"
    printf '\n## Leitura da última rodada\n'
    [[ -n "$lei" ]] && printf '%s\n' "$lei"
  } >"$tmp"
  mv -f "$tmp" "$REGISTRO"
  echo "coletar-estado: registro gravado em ${REGISTRO#"$VAULT"/}" >&2
}

[[ $GRAVAR -eq 1 ]] && gravar_registro

if [[ $FORMATO == json ]]; then
  printf '%s\n' "$DOC"
  exit 0
fi

# --- Renderização -----------------------------------------------------------
# Fases da mais adiantada para a menos: o que está pronto e o que trava vêm
# antes do que nem começou. Seção vazia imprime "—" em vez de sumir: o agente
# precisa distinguir "olhei e não tem" de "não olhei".
printf '%s' "$DOC" | jq -r --argjson fases "$FASES_JSON" '
  def col(n): (. + "                                        ")[0:n];
  def bloco(l): if (l | length) == 0 then "  —" else (l | join("\n")) end;
  # prosa do registro vem verbatim do arquivo: indenta para não quebrar a
  # leitura do relatório, e some quando só tem espaço em branco.
  def prosa: if (gsub("\\s"; "")) == "" then "    —"
             else (split("\n") | map(select(length > 0)) | map("    " + .) | join("\n")) end;
  def bloco(l; aviso): if (l | length) == 0 then "  — \(aviso)" else (l | join("\n")) end;
  def linha_task:
    "  - \(.id)  ·  \(.titulo)"
    + (if .estado  != "" then "\n      estado: \(.estado)" else "" end)
    + (if .dono    != "" then "\n      dono: \(.dono) desde \(.desde) [\(.dominio)]" else "" end)
    + (if .notas   != "" then "\n      notas: \(.notas[0:280])" else "" end);

  . as $r |

  "# estado: \($r.projeto)" + (if $r.pedido != $r.projeto then "   (pedido: \"\($r.pedido)\")" else "" end),
  "gerado em \($r.gerado_em) · janela: \($r.janela_origem) — mudanças desde \($r.desde)",
  "vault: projects/\($r.projeto)/ · MOC: \($r.moc) · \($r.adrs) ADR(s) em decisoes/",
  "",

  "## fontes",
  bloco([ $r.fontes[] | "  \(.estado|col(14))\(.fonte|col(12))\(.detalhe)" ]),
  "",

  "## registro da rodada anterior",
  ( if $r.registro.existe | not then "  — primeira rodada nesta máquina; nada gravado ainda (\($r.registro.caminho))"
    else
      "  \($r.registro.caminho) · coletado em \($r.registro.coletado_em)"
      + "\n\n  na sua fila desde:\n"
      + bloco([ $r.registro.fila[] | "    \(.chave|col(26))desde \(.desde) · \(.rodadas) rodada\(if .rodadas == 1 then "" else "s" end)" ])
      + "\n\n  decidido na conversa:\n" + ($r.registro.decidido | prosa)
      + "\n\n  adiado de propósito:\n"  + ($r.registro.adiado   | prosa)
      + "\n\n  leitura da última rodada:\n" + ($r.registro.leitura | prosa)
    end ),
  "",

  "## tasks por fase",
  ( [ $r.tasks[] | select(.arquivada == "") ] ) as $ativas |
  ( ( $fases | to_entries | map(select((.key|tonumber) <= 6))
      | sort_by(.key|tonumber) | reverse )[]
    | .value.title as $titulo | .value.callout as $callout
    | ( [ $ativas[] | select(.callout == $callout) ] ) as $g
    | "### \($titulo) (\($callout)) — \($g|length)"
      + (if $callout == "question" then "   <- é isto que espera homologação sua" else "" end)
      + "\n" + bloco([ $g[] | linha_task ])
  ),
  "",
  ( [ $r.tasks[] | select(.arquivada != "" and .data >= $r.desde) ]
    | sort_by(.data) | reverse ) as $arq |
  "### Arquivadas na janela — \($arq|length)",
  bloco([ $arq[] | "  - \(.data)  \(.arquivada|col(9))\(.id)  ·  \(.titulo)"
                   + (if .estado != "" then "\n      estado: \(.estado)" else "" end) ]),
  "",

  "## mudanças na janela",
  "### vault (checkpoints do vaultgit)",
  ( $r.mudancas_vault | group_by(.genero) | map("\(.[0].genero): \(length)") | join("   ") | "  " + . ),
  bloco([ $r.mudancas_vault[0:40][] | "  \(.data)  \(.genero|col(8))\(.acao)  \(.arquivo|sub("^projects/[^/]+/";""))" ]),
  ( if ($r.mudancas_vault|length) > 40 then "  … mais \(($r.mudancas_vault|length) - 40) arquivo(s) — use --janela menor para afunilar" else empty end),
  "",
  "### repos",
  bloco([ $r.repos[] |
    "  \(.path)"
    + (if .github != "" then "  ·  \(.github)" else "" end)
    + "\n      branch: \(.branch)"
    + (if .upstream != "" then " (upstream \(.upstream): \(.ahead) à frente, \(.behind) atrás)" else " (sem upstream — trabalho não publicado)" end)
    + (if .sujo > 0 then "\n      árvore suja: \(.sujo) caminho(s)" else "" end)
    + (if (.sem_upstream|length) > 0 then "\n      branches locais sem upstream: \(.sem_upstream | join(", "))" else "" end)
    + (if (.worktrees|length) > 1 then "\n      worktrees (\(.worktrees|length)): " + ([.worktrees[] | "\(.branch)"] | join(", ")) else "" end)
    + "\n      commits na janela: \(.commits|length)"
    + (if (.commits|length) >= 30 then " (teto de 30 — pode haver mais)" else "" end)
    + (if (.commits|length) > 0 then "\n" + ([ .commits[] | "        \(.sha)  \(.data)  \(.assunto)" ] | join("\n")) else "" end)
  ]),
  "",
  "### planos de sessão (ponteiro, não fonte)",
  bloco([ $r.planos[] | "  \(.data)  \(.arquivo)\n      \(.titulo)" ]),
  "",

  "## esperando você",
  ( [ $r.fontes[] | select(.fonte == "github") | select(.estado != "ok") | "(github \(.estado): \(.detalhe))" ] | .[0] // "" ) as $semgh |
  "### PRs abertos",
  bloco([ $r.esperando.prs[] |
    "  #\(.number)  \(.repo)  \(.headRefName)"
    + (if .isDraft then "  [rascunho]" else "" end)
    + (if (.reviewDecision // "") != "" then "  [\(.reviewDecision)]" else "  [sem review]" end)
    + "\n      \(.title)"
    + "\n      atualizado \(.updatedAt[0:10]) por \(.author.login // "?")" ]; $semgh),
  "### issues com label pedindo humano",
  bloco([ $r.esperando.issues[] | "  #\(.number)  \(.repo)  [\(.labels|join(", "))]\n      \(.title)   (atualizada \(.updatedAt[0:10]))" ]; $semgh),
  "### tasks em homologação",
  bloco([ $ativas[] | select(.callout == "question") | "  - \(.id)  ·  \(.titulo)" ]),
  "### notas avulsas do painel que citam o projeto",
  bloco([ $r.esperando.notas_avulsas[] | "  - \(.[0:400])" ]),
  "### notas de spec com seção de pendências",
  bloco([ $r.esperando.pendencias[0:15][] | "  \(.)" ]),
  ( if ($r.esperando.pendencias|length) > 15 then "  … e mais \(($r.esperando.pendencias|length) - 15)" else empty end),
  "",

  "## host",
  ( if $r.host == null then "  — nenhum host vinculado (nenhuma nota em hosts/ tem a tag \($r.projeto))"
    else
      "  \($r.host.alias)  ·  \($r.host.estado)" + (if $r.host.nota != "" then "  ·  \($r.host.nota | sub("^.*/ObsidianVault/";""))" else "" end)
      + (if ($r.host.containers|length) > 0 then
          "\n      no ar: \([$r.host.containers[]|select(.status|test("^Up"))]|length)"
          + "   fora: \([$r.host.containers[]|select(.status|test("^Up")|not)]|length)"
          + "\n      fora do ar:\n"
          + (bloco([ $r.host.containers[] | select(.status|test("^Up")|not) | "        \(.nome|col(30))\(.status)" ]))
        else "" end)
    end ),
  "",

  "## avisos",
  "  freitask doctor: \($r.avisos.doctor)",
  "  vault-lint:      \($r.avisos.vault_lint)"
'
