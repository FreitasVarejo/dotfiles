#!/bin/bash
# shellcheck shell=bash
# Checks do pacote 'nvim': versão do Neovim, tree-sitter CLI, .NET SDK + Roslyn
# LSP e os opcionais de preview de imagem. READ-ONLY: o warmup do lazy/Mason
# (que instala plugin) mora no setup.sh; a versão do fd que o Snacks exige é
# checada no hook do bash.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"

log_info "--- Neovim ---"
if command -v nvim &>/dev/null; then
  NVIM_VER=$(nvim --version | head -n1 | cut -d ' ' -f2)
  CLEAN_VER="${NVIM_VER#v}"
  MAJOR=$(echo "$CLEAN_VER" | cut -d. -f1)
  MINOR=$(echo "$CLEAN_VER" | cut -d. -f2)
  if [ "$MAJOR" -gt 0 ] || { [ "$MAJOR" -eq 0 ] && [ "$MINOR" -ge 9 ]; }; then
    log_success "Neovim encontrado ($NVIM_VER)"
  else
    log_warn "Neovim encontrado, mas versão antiga ($NVIM_VER). Recomendado v0.9+"
  fi
else
  log_missing "Neovim não encontrado."
  echo "    -> Sugestão: Baixar a release mais recente do Github (v0.9+)"
  fail_check
fi

echo ""
log_info "--- .NET SDK ---"
if [ -d "$HOME/.dotnet" ]; then
  log_success ".NET SDK encontrado em ~/.dotnet"
  ROSLYN_BIN=""
  for cand in \
    "$HOME/.local/share/nvim/mason/bin/roslyn" \
    "$HOME/.local/share/nvim/mason/bin/roslyn-language-server"; do
    if [ -x "$cand" ]; then
      ROSLYN_BIN="$cand"
      break
    fi
  done
  if [ -z "$ROSLYN_BIN" ]; then
    ROSLYN_BIN=$(command -v roslyn 2>/dev/null || command -v roslyn-language-server 2>/dev/null || true)
  fi
  if [ -n "$ROSLYN_BIN" ]; then
    log_success "Roslyn LSP disponível: $ROSLYN_BIN"
  else
    log_warn "Roslyn não encontrado (C# no Neovim ficará sem LSP)."
    echo "    -> Instalar via Mason: nvim --headless '+MasonInstall roslyn' +qa"
    echo "    -> Ou dotnet tool install --global csharp-ls"
  fi
else
  log_warn ".NET SDK não encontrado."
  echo "    -> Instalar: https://dotnet.microsoft.com/download"
fi

echo ""
log_info "--- Tree-sitter CLI ---"
if command -v tree-sitter &>/dev/null; then
  TS_VER=$(tree-sitter --version 2>&1 | head -n1)
  log_success "Tree-sitter CLI encontrado: $TS_VER"
else
  log_warn "tree-sitter CLI não encontrado."
  echo "    -> Baixe binário de: https://github.com/tree-sitter/tree-sitter/releases"
  echo "    -> Ou execute: cargo install tree-sitter-cli"
fi

echo ""
log_info "--- Freitask (plugin externo) ---"
# O freitask deixou de morar em nvim/lua/ e virou repo próprio. O spec do lazy
# se desativa em silêncio se o clone não existir (não vale derrubar o startup do
# Neovim por causa dele), então é aqui que a ausência precisa aparecer.
FREITASK_REPO="${FREITASK_REPO:-$HOME/dev/freitask.nvim}"
if [[ -f "$FREITASK_REPO/lua/freitask/init.lua" ]]; then
  log_success "freitask.nvim encontrado: $FREITASK_REPO"
else
  log_missing "freitask.nvim não encontrado em $FREITASK_REPO"
  echo "    -> setup.sh clona de git@github.com:FreitasVarejo/freitask.nvim.git."
  echo "    -> Sem ele: o picker <leader>ob some e a CLI 'freitask' falha."
  fail_check
fi

echo ""
log_info "--- Snacks.image optionals (preview de imagens inline) ---"
log_optional "Estes são opcionais; o picker e dashboard funcionam sem eles."
check_cmd "magick" "$PM_INSTALL imagemagick" "optional"
check_cmd "gs" "$PM_INSTALL ghostscript" "optional"
check_cmd "tectonic" "cargo install tectonic" "optional"
check_cmd "mndc" "cargo install mandown" "optional"

exit "$CHECK_FAILED"
