#!/bin/bash
# shellcheck shell=bash
# Checks do pacote 'nvim': versão do Neovim, tree-sitter CLI, .NET SDK + Roslyn
# LSP, smoke test do LazyVim/Snacks, e os opcionais de preview de imagem.

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
log_info "--- Neovim smoke (LazyVim/Mason/Snacks warmup) ---"
if command -v nvim &>/dev/null; then
  SMOKE_LOG=$(mktemp "${TMPDIR:-/tmp}/nvim-smoke.XXXXXX.log")
  if timeout 90 nvim --headless \
    -c 'lua require("lazy").load({ plugins = { "folke/snacks.nvim" } })' \
    -c 'lua local ok, snacks = pcall(require, "snacks"); if ok then pcall(function() snacks.picker.smart() end) end' \
    -c 'qa' >"$SMOKE_LOG" 2>&1; then
    log_success "Smoke test do Neovim completou sem timeout."
    if grep -qiE 'E5113|fd < 8\.4|fd.*not found' "$SMOKE_LOG"; then
      log_warn "Possível incompatibilidade de fd com Snacks picker detectada (ver $SMOKE_LOG)."
    fi
  else
    log_warn "Smoke test excedeu timeout (90s). Pode ser primeira execução do Mason."
    echo "    -> Tente novamente após: nvim --headless '+Mason' +qa"
  fi
  rm -f "$SMOKE_LOG"
else
  log_info "Smoke pulado (nvim ausente)."
fi

echo ""
log_info "--- Snacks.image optionals (preview de imagens inline) ---"
log_optional "Estes são opcionais; o picker e dashboard funcionam sem eles."
check_cmd "magick" "$PM_INSTALL imagemagick" "optional"
check_cmd "gs" "$PM_INSTALL ghostscript" "optional"
check_cmd "tectonic" "cargo install tectonic" "optional"
check_cmd "mndc" "cargo install mandown" "optional"

exit "$CHECK_FAILED"
