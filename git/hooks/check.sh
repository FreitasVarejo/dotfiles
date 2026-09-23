#!/bin/bash
# shellcheck shell=bash
# Check do pacote 'git': identidade global e helper de credenciais. READ-ONLY —
# se faltar, apenas avisa (a configuração interativa vive em git/hooks/setup.sh).

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"

log_info "--- Git Identity ---"
git_name=$(git config --global user.name 2>/dev/null)
git_email=$(git config --global user.email 2>/dev/null)

if [ -n "$git_name" ] && [ -n "$git_email" ]; then
  log_success "Git identity configurada: $git_name <$git_email>"
else
  log_warn "Git identity não configurada (user.name / user.email ausentes)."
  echo "    -> Execute ./setup.sh (git/hooks/setup.sh pergunta e configura)."
fi

echo ""
log_info "--- Credential helper ---"
# git/config entrega a credencial HTTPS do GitHub ao gh. Só aviso, nunca
# fail_check: os remotes são SSH, e sem o gh o git apenas volta a pedir senha
# num clone HTTPS. Se o gh está logado é o hook do claude que confere.
helper=$(git config --get-urlmatch credential.helper https://github.com 2>/dev/null)
if [[ "$helper" != *"gh auth git-credential"* ]]; then
  log_optional "credential.helper do github.com = '${helper:-<nenhum>}' (o config do repo pede o gh)."
elif command -v gh &>/dev/null; then
  log_success "HTTPS do GitHub autentica pelo gh ($(command -v gh))"
else
  log_warn "credential.helper aponta para o gh, mas o gh não está no PATH."
  echo "    -> Sugestão: $PM_INSTALL gh"
  echo "    -> Até instalar, clone HTTPS do GitHub pede senha (SSH não é afetado)."
fi

if [ -s "$HOME/.git-credentials" ]; then
  log_warn "\$HOME/.git-credentials tem conteúdo — são tokens em TEXTO PLANO."
  echo "    -> Resíduo do helper 'store'. Revogue os tokens e apague o arquivo."
fi

exit "$CHECK_FAILED"
