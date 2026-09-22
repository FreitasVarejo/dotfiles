#!/bin/bash
# shellcheck shell=bash
# Gera um zip por skill marcada `web` (metadata.surfaces no SKILL.md), a partir
# do mesmo claude/.claude/skills/ que o stow instala — fonte única (ADR 0007 e
# 0010 do projeto workflow-ia). O upload no claude.ai (Settings > Skills) é
# manual; o check.sh avisa quando a cópia sincronizada divergir do repo.
#
# Uso: claude/hooks/build-web-zip.sh [dir-de-saida]
#      (padrão: ${XDG_CACHE_HOME:-~/.cache}/dotfiles/claude-skills-web)

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"
# shellcheck source=./mcp-servers.sh
. "$(dirname "${BASH_SOURCE[0]}")/mcp-servers.sh"

OUT_DIR="${1:-${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/claude-skills-web}"
mkdir -p "$OUT_DIR"

if ! command -v python3 &>/dev/null; then
  log_error "python3 não encontrado (usado para gerar os zips sem depender do 'zip')."
  exit 1
fi

count=0
while IFS= read -r skill_dir; do
  skill=$(basename "$skill_dir")
  surfaces=$(skill_surfaces "$skill_dir")
  [[ ",$surfaces," == *,web,* ]] || continue
  out="$OUT_DIR/$skill.zip"
  python3 - "$skill_dir" "$out" <<'PYEOF'
import pathlib, sys, zipfile
src, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for f in sorted(p for p in src.rglob("*") if p.is_file()):
        z.write(f, f"{src.name}/{f.relative_to(src)}")
PYEOF
  log_success "$skill -> $out"
  count=$((count + 1))
done < <(find "$CLAUDE_PKG_SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

if ((count == 0)); then
  log_warn "Nenhuma skill marcada 'web' em $CLAUDE_PKG_SKILLS_DIR."
else
  echo ""
  log_info "$count zip(s) em $OUT_DIR. Suba em claude.ai > Settings > Skills; o healthcheck avisa quando divergir."
fi
