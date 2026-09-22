#!/bin/bash
# shellcheck shell=bash
# Checks READ-ONLY do pacote 'claude': skills globais visíveis para o Claude
# Code (e para o Cursor CLI, que lê o mesmo ~/.claude/skills), referências
# entre skills, espelho das skills `web` no claude.ai e MCP servers do mapa.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"
# shellcheck source=./mcp-servers.sh
. "$(dirname "${BASH_SOURCE[0]}")/mcp-servers.sh"

log_info "--- Claude Code ---"
if command -v claude &>/dev/null; then
  CC_VER=$(claude --version 2>&1 | head -n1)
  log_success "Claude Code encontrado: $CC_VER ($(command -v claude))"
else
  log_optional "Claude Code não encontrado (no WSL do trabalho o leitor das skills é o Cursor CLI)."
fi

# 1. Skills stowadas ----------------------------------------------------------
# Verde aqui significa "toda skill do pacote está visível em ~/.claude/skills".
# Só a skill é symlink, nunca ~/.claude inteiro (tem estado) nem ~/.claude/skills
# inteiro (o Claude Code escreve synced/ lá dentro; dobrado, cairia no repo).
echo ""
log_info "--- Skills globais (~/.claude/skills) ---"
if [[ -L "$CLAUDE_HOME_SKILLS_DIR" ]]; then
  log_warn "\$HOME/.claude/skills é um symlink (stow dobrou o diretório): synced/ do claude.ai vai cair dentro do repo."
  echo "    -> Corrigir: ./setup.sh (o hook de setup do pacote 'claude' desdobra)."
fi

mapfile -t PKG_SKILLS < <(find "$CLAUDE_PKG_SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
for skill in "${PKG_SKILLS[@]}"; do
  link="$CLAUDE_HOME_SKILLS_DIR/$skill"
  if [[ -f "$link/SKILL.md" && "$(readlink -f "$link")" == "$CLAUDE_PKG_SKILLS_DIR/$skill" ]]; then
    log_success "skill '$skill' visível"
  else
    log_missing "skill '$skill' não está em ~/.claude/skills"
    echo "    -> Rodar: ./setup.sh"
    fail_check
  fi
done

# 2. Referências entre skills -------------------------------------------------
# Skill vendorada que cita outra ("Skill tool with \"grilling\"", "/grilling")
# precisa que a citada exista no pacote. Casca quebrada vira vermelho.
echo ""
log_info "--- Referências entre skills ---"
REF_OK=true
for skill in "${PKG_SKILLS[@]}"; do
  md="$CLAUDE_PKG_SKILLS_DIR/$skill/SKILL.md"
  # shellcheck disable=SC2016  # crases literais no padrão, não expansão
  mapfile -t refs < <(grep -oE 'Skill tool[^"]*"[a-z0-9-]+"|`/[a-z][a-z0-9-]+`' "$md" |
    grep -oE '"[a-z0-9-]+"|/[a-z][a-z0-9-]+' | tr -d '"/' | sort -u)
  for ref in "${refs[@]}"; do
    [[ "$ref" == "$skill" ]] && continue
    # Caminhos de filesystem que aparecem entre crases não são skills.
    case "$ref" in tmp|dev|home|usr|etc|var|bin|opt|proc) continue ;; esac
    if [[ -f "$CLAUDE_PKG_SKILLS_DIR/$ref/SKILL.md" ]]; then
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
  surfaces=$(skill_surfaces "$CLAUDE_PKG_SKILLS_DIR/$skill")
  [[ ",$surfaces," == *,web,* ]] || continue
  WEB_ANY=true
  mirror=$(find "$CLAUDE_HOME_SKILLS_DIR/synced" -mindepth 2 -maxdepth 2 -type d -name "$skill" 2>/dev/null | head -n1)
  if [[ -z "$mirror" ]]; then
    log_warn "skill 'web' '$skill' sem espelho em ~/.claude/skills/synced — ainda não subiu para o claude.ai"
    echo "    -> Gerar o zip: claude/hooks/build-web-zip.sh; subir em claude.ai > Skills"
  elif diff -rq "$CLAUDE_PKG_SKILLS_DIR/$skill" "$mirror" &>/dev/null; then
    log_success "skill 'web' '$skill' igual ao espelho do claude.ai"
  else
    log_warn "skill 'web' '$skill' diverge do espelho do claude.ai — re-subir o zip"
    echo "    -> Ver: diff -rq $CLAUDE_PKG_SKILLS_DIR/$skill $mirror"
  fi
done
[[ "$WEB_ANY" == true ]] || log_optional "Nenhuma skill marcada 'web'."

# 4. MCP servers do mapa -------------------------------------------------------
echo ""
log_info "--- MCP servers (mapa em claude/hooks/mcp-servers.sh) ---"
if command -v claude &>/dev/null; then
  CC_MCP_LIST=$(claude mcp list 2>/dev/null)
  if command -v python3 &>/dev/null; then
    while IFS=$'\t' read -r mcp_name mcp_verdict; do
      [[ -n "$mcp_name" ]] || continue
      case "$mcp_verdict" in
        ok) log_success "MCP server '$mcp_name' registrado e em dia (user scope)" ;;
        add) log_warn "MCP server '$mcp_name' não registrado. Execute ./setup.sh para registrar." ;;
        update)
          log_warn "MCP server '$mcp_name' registrado com configuração DIFERENTE do mapa."
          echo "    -> Reaplicar: ./setup.sh"
          ;;
        invalid) log_warn "MCP server '$mcp_name': JSON inválido em mcp-servers.sh" ;;
      esac
    done < <(
      for mcp_name in "${!CLAUDE_MCP_SERVERS[@]}"; do
        printf '%s\t%s\n' "$mcp_name" "${CLAUDE_MCP_SERVERS[$mcp_name]}"
      done | mcp_plan
    )
  else
    log_optional "Sem python3: configuração dos MCP servers não comparada com o mapa."
  fi
  if grep -q "^obsidian:" <<<"$CC_MCP_LIST"; then
    log_warn "MCP server 'obsidian' (Local REST API) ainda registrado; saiu do mapa (ADR 0008)."
    echo "    -> Remover: claude mcp remove obsidian --scope user"
  fi
else
  log_optional "Sem Claude Code: registro de MCP servers não verificado."
fi

# Duas perguntas DIFERENTES, e confundi-las dá falso negativo: o `gh` prefere
# $GITHUB_TOKEN à credencial que ele mesmo guardou, então uma variável morta no
# ambiente faz `gh auth status` reprovar uma máquina perfeitamente autenticada.
# Neutralizar a variável isola a primeira pergunta ("existe credencial
# própria?") da segunda ("tem segredo solto no ambiente?"). `env -u` a REMOVE,
# em vez de defini-la vazia: "vazia" e "ausente" não são a mesma coisa para
# todo programa, e aqui a pergunta é sobre ausência.
if ! command -v gh &>/dev/null; then
  log_optional "Sem gh: credencial do MCP 'github' não verificada."
elif env -u GITHUB_TOKEN gh auth status &>/dev/null; then
  log_success "gh tem credencial própria (o MCP 'github' a busca por 'gh auth token')"
else
  log_warn "gh sem credencial própria. Rode 'gh auth login --skip-ssh-key'."
  echo "    -> o MCP 'github' monta o header com 'gh auth token'; sem isso ele falha com 401."
fi

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  log_warn "GITHUB_TOKEN está no ambiente e SOMBREIA a credencial do gh."
  echo "    -> Segredo exportado é herdado por todo processo filho, inclusive agentes."
  echo "    -> Remova o export de ~/.bashrc.local e abra um terminal novo."
fi

exit "$CHECK_FAILED"
