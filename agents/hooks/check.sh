#!/bin/bash
# shellcheck shell=bash
# Checks READ-ONLY do pacote 'agents': skills visíveis para os agentes (Claude
# Code e Cursor CLI leem o mesmo ~/.claude/skills), referências entre skills,
# espelho das skills `web` no claude.ai, MCP servers de mcp/ e o deny de
# permissions/deny.json em cada agente presente.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log_info "--- Agentes ---"
if command -v claude &>/dev/null; then
  CC_VER=$(claude --version 2>&1 | head -n1)
  log_success "Claude Code encontrado: $CC_VER ($(command -v claude))"
else
  log_optional "Claude Code não encontrado (no WSL do trabalho o agente é o Cursor CLI)."
fi
if [[ -d "$CURSOR_HOME" ]]; then
  log_success "Cursor encontrado (${CURSOR_HOME/#$HOME/\~})"
else
  log_optional "Cursor não encontrado (${CURSOR_HOME/#$HOME/\~} não existe)."
fi

# 1. Skills linkadas ----------------------------------------------------------
# Verde aqui significa "toda skill do pacote está visível em cada diretório de
# skills dos agentes". Só a skill é symlink, nunca o diretório inteiro: o
# Claude Code escreve synced/ lá dentro, e um diretório-symlink a poria no repo.
mapfile -t PKG_SKILLS < <(package_skills)
for dir in "${AGENT_SKILL_DIRS[@]}"; do
  echo ""
  log_info "--- Skills globais (${dir/#$HOME/\~}) ---"
  if [[ -L "$dir" ]]; then
    log_warn "${dir/#$HOME/\~} é um symlink: synced/ do claude.ai cairia fora do lugar."
    echo "    -> Corrigir: ./setup.sh (o hook do pacote 'agents' o troca por diretório real)."
  fi
  for skill in "${PKG_SKILLS[@]}"; do
    link="$dir/$skill"
    if [[ -f "$link/SKILL.md" && "$(readlink -f "$link")" == "$AGENTS_SKILLS_DIR/$skill" ]]; then
      log_success "skill '$skill' visível"
    else
      log_missing "skill '$skill' não está em ${dir/#$HOME/\~}"
      echo "    -> Rodar: ./setup.sh"
      fail_check
    fi
  done
done

# 2. Referências entre skills -------------------------------------------------
# Skill vendorada que cita outra ("Skill tool with \"grilling\"", "/grilling")
# precisa que a citada exista no pacote. Casca quebrada vira vermelho.
echo ""
log_info "--- Referências entre skills ---"
REF_OK=true
for skill in "${PKG_SKILLS[@]}"; do
  md="$AGENTS_SKILLS_DIR/$skill/SKILL.md"
  # shellcheck disable=SC2016  # crases literais no padrão, não expansão
  mapfile -t refs < <(grep -oE 'Skill tool[^"]*"[a-z0-9-]+"|`/[a-z][a-z0-9-]+`' "$md" |
    grep -oE '"[a-z0-9-]+"|/[a-z][a-z0-9-]+' | tr -d '"/' | sort -u)
  for ref in "${refs[@]}"; do
    [[ "$ref" == "$skill" ]] && continue
    # Caminhos de filesystem que aparecem entre crases não são skills.
    case "$ref" in tmp|dev|home|usr|etc|var|bin|opt|proc) continue ;; esac
    if [[ -f "$AGENTS_SKILLS_DIR/$ref/SKILL.md" ]]; then
      log_success "'$skill' cita '$ref' (existe)"
    else
      log_missing "'$skill' cita '$ref', que não está no pacote"
      REF_OK=false
      fail_check
    fi
  done
done
[[ "$REF_OK" == true ]] && log_success "Nenhuma referência quebrada"

# 3. Espelho das skills `web` no claude.ai ------------------------------------
# O que se sobe para o claude.ai sincroniza de volta para
# ~/.claude/skills/synced/<bucket>/<skill>/. Essa cópia é o espelho do canal
# (ADR 0010): divergiu ou não existe = re-subir o zip. Aviso, nunca falha — o
# healthcheck não consegue corrigir um canal de upload manual.
echo ""
log_info "--- Espelho das skills 'web' no claude.ai ---"
WEB_ANY=false
for skill in "${PKG_SKILLS[@]}"; do
  surfaces=$(skill_surfaces "$AGENTS_SKILLS_DIR/$skill")
  [[ ",$surfaces," == *,web,* ]] || continue
  WEB_ANY=true
  mirror=$(find "$CLAUDE_SYNCED_SKILLS_DIR" -mindepth 2 -maxdepth 2 -type d -name "$skill" 2>/dev/null | head -n1)
  if [[ -z "$mirror" ]]; then
    log_warn "skill 'web' '$skill' sem espelho em ~/.claude/skills/synced — ainda não subiu para o claude.ai"
    echo "    -> Gerar o zip: agents/hooks/build-web-zip.sh; subir em claude.ai > Skills"
  elif diff -rq "$AGENTS_SKILLS_DIR/$skill" "$mirror" &>/dev/null; then
    log_success "skill 'web' '$skill' igual ao espelho do claude.ai"
  else
    log_warn "skill 'web' '$skill' diverge do espelho do claude.ai — re-subir o zip"
    echo "    -> Ver: diff -rq $AGENTS_SKILLS_DIR/$skill $mirror"
  fi
done
[[ "$WEB_ANY" == true ]] || log_optional "Nenhuma skill marcada 'web'."

# 4. MCP servers ---------------------------------------------------------------
# config_failed <status> <o-que> — agent_config caiu: o motivo já foi para
# stderr. Arquivo do repo inválido (2) é vermelho, como skill quebrada; arquivo
# do agente ilegível (3) é aviso, porque o conserto é à mão e fora do repo.
config_failed() {
  if [[ "$1" -eq 2 ]]; then
    log_missing "$2: arquivo do repo inválido (erro acima)"
    fail_check
  else
    log_warn "$2: não deu para comparar (erro acima)"
  fi
}

# report_mcp <agente> <arquivo> — compara o arquivo do agente com agents/mcp/.
report_mcp() {
  local agent="$1" file="$2" name verdict out
  out=$(agent_config mcp-plan "$agent" "$file" "$AGENTS_MCP_DIR") ||
    { config_failed $? "$agent: MCP"; return; }
  while IFS=$'\t' read -r name verdict; do
    [[ -n "$name" ]] || continue
    case "$verdict" in
      ok) log_success "$agent: MCP '$name' registrado e em dia" ;;
      add) log_warn "$agent: MCP '$name' não registrado. Execute ./setup.sh para registrar." ;;
      update)
        log_warn "$agent: MCP '$name' registrado com configuração DIFERENTE do repo."
        echo "    -> Reaplicar: ./setup.sh"
        ;;
      skip) log_optional "$agent: MCP '$name' não se aplica (ver agents/mcp/README.md)" ;;
    esac
  done <<<"$out"
}

echo ""
log_info "--- MCP servers (agents/mcp/) ---"
if ! command -v python3 &>/dev/null; then
  log_optional "Sem python3: configuração dos MCP servers não comparada com o repo."
else
  if command -v claude &>/dev/null; then
    report_mcp claude "$CLAUDE_MCP_CONFIG"
  else
    log_optional "Sem Claude Code: registro de MCP nele não verificado."
  fi
  if [[ -d "$CURSOR_HOME" ]]; then
    report_mcp cursor "$CURSOR_MCP_CONFIG"
  else
    log_optional "Sem Cursor: registro de MCP nele não verificado."
  fi
fi
# MCPs que saíram do workflow. O setup só acrescenta e nunca remove (ADR 0024),
# então o resto que ficou numa máquina é limpo à mão; aqui ele só é apontado.
# nome -> ADR que o tirou.
declare -A RETIRED_MCP=(
  [obsidian]="0008"
  [git]="0025" [github]="0025" [ssh]="0025" [docker]="0025"
)

# report_retired <agente> <arquivo> <como-remover> — lido do arquivo, e não de
# `claude mcp list`, que health-checka cada servidor pela rede para responder
# uma pergunta local.
report_retired() {
  local agent="$1" file="$2" how="$3" name
  while IFS= read -r name; do
    [[ -n "${RETIRED_MCP[$name]:-}" ]] || continue
    log_warn "$agent: MCP '$name' ainda registrado; saiu do workflow (ADR ${RETIRED_MCP[$name]})."
    echo "    -> Remover: ${how//<nome>/$name}"
  done < <(agent_config mcp-registered "$file" 2>/dev/null)
}

if command -v python3 &>/dev/null; then
  command -v claude &>/dev/null &&
    report_retired claude "$CLAUDE_MCP_CONFIG" "claude mcp remove <nome> --scope user"
  [[ -f "$CURSOR_MCP_CONFIG" ]] &&
    report_retired cursor "$CURSOR_MCP_CONFIG" "apagar '<nome>' de ${CURSOR_MCP_CONFIG/#$HOME/\~}"
fi

# Duas perguntas DIFERENTES, e confundi-las dá falso negativo: o `gh` prefere
# $GITHUB_TOKEN à credencial que ele mesmo guardou, então uma variável morta no
# ambiente faz `gh auth status` reprovar uma máquina perfeitamente autenticada.
# Neutralizar a variável isola a primeira pergunta ("existe credencial
# própria?") da segunda ("tem segredo solto no ambiente?"). `env -u` a REMOVE,
# em vez de defini-la vazia: "vazia" e "ausente" não são a mesma coisa para
# todo programa, e aqui a pergunta é sobre ausência.
if ! command -v gh &>/dev/null; then
  log_optional "Sem gh: credencial do GitHub não verificada."
elif env -u GITHUB_TOKEN gh auth status &>/dev/null; then
  log_success "gh tem credencial própria (é por ela que os agentes falam com o GitHub)"
else
  log_warn "gh sem credencial própria. Rode 'gh auth login --skip-ssh-key'."
  echo "    -> os agentes falam com o GitHub pelo 'gh'; sem credencial, cada chamada falha."
fi

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  log_warn "GITHUB_TOKEN está no ambiente e SOMBREIA a credencial do gh."
  echo "    -> Segredo exportado é herdado por todo processo filho, inclusive agentes."
  echo "    -> Remova o export de ~/.bashrc.local e abra um terminal novo."
fi

# 5. Deny de permissões ---------------------------------------------------------
# O deny guarda o que nenhum agente deve ler ou rodar (os segredos que a regra
# do GITHUB_TOKEN tira do ambiente). Faltar é aviso: o setup.sh mescla.
# report_deny <agente> <arquivo>
report_deny() {
  local agent="$1" file="$2" missing
  missing=$(agent_config deny-plan "$agent" "$file" "$AGENTS_DENY_FILE") ||
    { config_failed $? "$agent: deny"; return; }
  if [[ -z "$missing" ]]; then
    log_success "$agent: deny em dia (${file/#$HOME/\~})"
  else
    log_warn "$agent: faltam $(wc -l <<<"$missing") regra(s) de deny em ${file/#$HOME/\~}"
    while IFS= read -r rule; do echo "    -> $rule"; done <<<"$missing"
    echo "    -> Aplicar: ./setup.sh"
  fi
}

echo ""
log_info "--- Deny de permissões (agents/permissions/deny.json) ---"
if ! command -v python3 &>/dev/null; then
  log_optional "Sem python3: deny não comparado com o repo."
else
  if command -v claude &>/dev/null; then
    report_deny claude "$CLAUDE_SETTINGS"
  else
    log_optional "Sem Claude Code: deny dele não verificado."
  fi
  if [[ -d "$CURSOR_HOME" ]]; then
    report_deny cursor "$CURSOR_CLI_CONFIG"
  else
    log_optional "Sem Cursor: deny dele não verificado."
  fi
fi

exit "$CHECK_FAILED"
