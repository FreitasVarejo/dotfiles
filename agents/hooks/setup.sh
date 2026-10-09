#!/bin/bash
# shellcheck shell=bash
# Setup do pacote 'agents' (pacote só de hook: o setup.sh raiz não o stowa):
#   - linka cada skill em cada diretório de skills dos agentes;
#   - linka as instruções de usuário (instructions/) no Claude Code;
#   - registra os MCP servers de mcp/ no Claude Code e no Cursor;
#   - mescla permissions/deny.json no deny do Claude Code e do Cursor;
#   - mescla settings/claude.json no settings.json do Claude Code.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# points_into_repo <symlink> — o link aponta (mesmo pendurado) para o diretório
# de skills deste repo ou para algo dentro dele, no caminho atual ou no do
# antigo pacote 'claude'? O próprio diretório conta: é o "dobrado" do stow. Só
# links assim são do setup; qualquer outro é de alguém e não se mexe nele.
points_into_repo() {
  local target base
  target=$(link_target "$1")
  for base in "$AGENTS_SKILLS_DIR" "$AGENTS_LEGACY_SKILLS_DIR"; do
    [[ "$target" == "$base" || "$target" == "$base"/* ]] && return 0
  done
  return 1
}

# unfold_skills_dir <dir> — resto do tempo do stow: o diretório inteiro era um
# symlink para o repo, e o claude.ai sincronizava synced/ lá dentro. O link sai,
# o diretório nasce de verdade, e o synced/ volta para onde o Claude Code o lê.
unfold_skills_dir() {
  local dir="$1" old
  old=$(realpath -m "$dir")
  rm "$dir"
  mkdir -p "$dir"
  if [[ -d "$old/synced" && ! -e "$dir/synced" ]]; then
    mv "$old/synced" "$dir/synced"
    log_info "synced/ do claude.ai movido de ${old/#$HOME/\~} para ${dir/#$HOME/\~}"
  fi
  log_warn "${dir/#$HOME/\~} era symlink para o repo; virou diretório real"
}

# Um symlink por skill, nunca o diretório inteiro: o Claude Code escreve
# synced/ (skills sincronizadas do claude.ai) ali dentro, e ~/.claude tem estado
# (~/.claude.json, histórico, trust). Como o diretório é criado de verdade antes
# de linkar, não há "dobra" possível.
link_skills() {
  local dir entry skill link want
  local -a skills
  mapfile -t skills < <(package_skills)

  for dir in "${AGENT_SKILL_DIRS[@]}"; do
    if [[ -L "$dir" ]]; then
      if ! points_into_repo "$dir"; then
        # Linkar "dentro" de um symlink alheio poria as skills em outro lugar.
        log_warn "${dir/#$HOME/\~} é symlink para fora do repo; pulando este diretório"
        continue
      fi
      unfold_skills_dir "$dir"
    fi
    mkdir -p "$dir"

    # Links do repo pendurados (skill apagada ou movida, inclusive os do antigo
    # pacote 'claude') saem; o laço seguinte recria os que ainda existem.
    for entry in "$dir"/*; do
      [[ -L "$entry" && ! -e "$entry" ]] || continue
      if points_into_repo "$entry"; then
        rm "$entry"
        log_info "Link pendurado removido: ${entry/#$HOME/\~}"
      fi
    done

    for skill in "${skills[@]}"; do
      link="$dir/$skill"
      want="$AGENTS_SKILLS_DIR/$skill"
      if [[ -L "$link" && "$(readlink -f "$link")" == "$want" ]]; then
        continue
      elif [[ -L "$link" ]] && ! points_into_repo "$link"; then
        log_warn "${link/#$HOME/\~} é symlink para fora do repo; não mexo"
      elif [[ -e "$link" && ! -L "$link" ]]; then
        log_warn "${link/#$HOME/\~} é arquivo/diretório real; não mexo"
      elif ln -sfn "$want" "$link"; then
        log_success "skill '$skill' linkada em ${dir/#$HOME/\~}"
      else
        log_warn "Falha ao linkar a skill '$skill' em ${dir/#$HOME/\~}"
      fi
    done
  done
  log_success "Skills do pacote linkadas em: ${AGENT_SKILL_DIRS[*]/#$HOME/\~}"
}

# link_instruction <fonte> <destino> — um symlink por arquivo (ADR 0026). Destino
# que já existe e não é link do repo (arquivo escrito à mão, link alheio) não se
# toca: o aviso diz o que fazer.
link_instruction() {
  local want="$1" link="$2"
  if [[ -L "$link" && "$(readlink -f "$link")" == "$want" ]]; then
    return 0
  elif [[ -L "$link" ]] && ! points_into_instructions "$link"; then
    log_warn "${link/#$HOME/\~} é symlink para fora do repo; não mexo"
  elif [[ -e "$link" && ! -L "$link" ]]; then
    log_warn "${link/#$HOME/\~} é arquivo real; não mexo (junte-o a ${want/#$HOME/\~} e apague)"
  elif mkdir -p "$(dirname "$link")" && ln -sfn "$want" "$link"; then
    log_success "instrução linkada: ${link/#$HOME/\~}"
  else
    log_warn "Falha ao linkar ${link/#$HOME/\~}"
  fi
}

link_instructions() {
  if ! command -v claude &>/dev/null; then
    log_optional "claude não encontrado, pulando as instruções de usuário"
    return
  fi

  local src dest
  while IFS=$'\t' read -r src dest; do
    [[ -n "$src" ]] && link_instruction "$src" "$dest"
  done < <(instruction_links)

  # Máquina sem arquivo próprio: o link de outra época (arquivo apagado ou
  # renomeado) sai. Link que não é do repo fica como está.
  if [[ -L "$CLAUDE_MACHINE_MD" ]] &&
    [[ ! -f "$AGENTS_INSTRUCTIONS_DIR/machines/$AGENTS_MACHINE.md" ]] &&
    points_into_instructions "$CLAUDE_MACHINE_MD"; then
    rm "$CLAUDE_MACHINE_MD"
    log_info "Link removido: ${CLAUDE_MACHINE_MD/#$HOME/\~} (sem machines/$AGENTS_MACHINE.md)"
  fi
  log_success "Instruções de usuário processadas (host: $AGENTS_MACHINE)"
}

register_claude_mcp_servers() {
  if ! command -v claude &>/dev/null; then
    log_optional "claude não encontrado, pulando o registro de MCP no Claude Code"
    return
  fi

  local name verdict plan
  if ! load_mcp_servers ||
    ! plan=$(agent_config mcp-plan claude "$CLAUDE_MCP_CONFIG" "$AGENTS_MCP_DIR"); then
    log_warn "Claude Code: MCPs não registrados (erro acima)"
    return
  fi

  while IFS=$'\t' read -r name verdict; do
    [[ -n "$name" ]] || continue
    case "$verdict" in
      ok)
        log_success "Claude Code: MCP '$name' já registrado e em dia"
        continue
        ;;
      update)
        # `add-json` não sobrescreve servidor existente: atualizar é remover e
        # registrar de novo. A remoção é tolerante a falha de propósito — se o
        # servidor sumiu entre o plano e aqui, o add seguinte resolve.
        claude mcp remove "$name" --scope user &>/dev/null || true
        ;;
    esac
    if claude mcp add-json "$name" "${MCP_SERVERS[$name]}" --scope user &>/dev/null; then
      if [[ "$verdict" == "update" ]]; then
        log_success "Claude Code: MCP '$name' atualizado (configuração havia mudado)"
      else
        log_success "Claude Code: MCP '$name' registrado"
      fi
    else
      log_warn "Claude Code: falha ao registrar o MCP '$name'"
    fi
  done <<<"$plan"
}

# O Cursor não tem um `mcp add`: a config de usuário é o ~/.cursor/mcp.json, e
# o helper mescla nele por nome, sem tocar no que não veio do repo.
register_cursor_mcp_servers() {
  if [[ ! -d "$CURSOR_HOME" ]]; then
    log_optional "Sem ${CURSOR_HOME/#$HOME/\~}, pulando o registro de MCP no Cursor"
    return
  fi

  local name verdict out
  if ! out=$(agent_config mcp-apply cursor "$CURSOR_MCP_CONFIG" "$AGENTS_MCP_DIR"); then
    log_warn "Cursor: MCPs não registrados (erro acima)"
    return
  fi
  while IFS=$'\t' read -r name verdict; do
    [[ -n "$name" ]] || continue
    case "$verdict" in
      ok) log_success "Cursor: MCP '$name' já em dia" ;;
      add) log_success "Cursor: MCP '$name' registrado" ;;
      update) log_success "Cursor: MCP '$name' atualizado (configuração havia mudado)" ;;
      skip) log_warn "Cursor: MCP '$name' pulado (usa chave só do Claude Code; ver agents/mcp/README.md)" ;;
    esac
  done <<<"$out"
}

# apply_deny <agente> <arquivo> — acrescenta o que falta de deny.json.
apply_deny() {
  local agent="$1" file="$2" added
  if ! added=$(agent_config deny-apply "$agent" "$file" "$AGENTS_DENY_FILE"); then
    log_warn "$agent: deny não aplicado em ${file/#$HOME/\~} (erro acima)"
  elif [[ -z "$added" ]]; then
    log_success "$agent: deny em dia (${file/#$HOME/\~})"
  else
    while IFS= read -r rule; do
      log_success "$agent: deny += $rule"
    done <<<"$added"
  fi
}

# apply_claude_settings — leva settings/claude.json ao settings.json do Claude Code.
apply_claude_settings() {
  local out key verdict
  if ! out=$(agent_config settings-apply claude "$CLAUDE_SETTINGS" "$AGENTS_CLAUDE_SETTINGS_FILE"); then
    log_warn "claude: settings não mesclado em ${CLAUDE_SETTINGS/#$HOME/\~} (erro acima)"
  elif [[ -z "$out" ]]; then
    log_success "claude: settings em dia (${CLAUDE_SETTINGS/#$HOME/\~})"
  else
    while IFS=$'\t' read -r key verdict; do
      log_success "claude: settings $key ($verdict)"
    done <<<"$out"
  fi
}

log_info "Linkando as skills..."
link_skills

echo ""
log_info "Linkando as instruções de usuário..."
link_instructions

if ! command -v python3 &>/dev/null; then
  log_warn "python3 não encontrado; MCPs e permissões não foram aplicados."
  exit 0
fi

echo ""
log_info "Registrando MCP servers..."
register_claude_mcp_servers
register_cursor_mcp_servers

echo ""
log_info "Aplicando o deny de permissions/deny.json..."
if command -v claude &>/dev/null; then
  apply_deny claude "$CLAUDE_SETTINGS"
else
  log_optional "claude não encontrado, pulando o deny do Claude Code"
fi
if [[ -d "$CURSOR_HOME" ]]; then
  apply_deny cursor "$CURSOR_CLI_CONFIG"
else
  log_optional "Sem ${CURSOR_HOME/#$HOME/\~}, pulando o deny do Cursor"
fi

echo ""
log_info "Mesclando settings/claude.json..."
if command -v claude &>/dev/null; then
  apply_claude_settings
else
  log_optional "claude não encontrado, pulando o settings do Claude Code"
fi
