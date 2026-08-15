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
# git/config pede o helper libsecret, que NÃO vem com o git: é um binário à
# parte em git-core. Sem ele, toda operação por HTTPS falha com "credential-
# libsecret is not a git command" — pior que o `store` que ele substituiu.
helper=$(git config --get credential.helper 2>/dev/null)
if [ "$helper" != "libsecret" ]; then
  log_optional "credential.helper = '${helper:-<nenhum>}' (o config do repo pede libsecret)."
elif git --exec-path >/dev/null 2>&1 && [ -x "$(git --exec-path)/git-credential-libsecret" ]; then
  log_success "git-credential-libsecret encontrado"
else
  log_missing "credential.helper = libsecret, mas o binário não existe."
  echo "    -> Sugestão: $PM_INSTALL git-credential-libsecret"
  echo "    -> Até instalar, autenticação por HTTPS falha (SSH não é afetado)."
  fail_check
fi

if [ -s "$HOME/.git-credentials" ]; then
  log_warn "\$HOME/.git-credentials tem conteúdo — são tokens em TEXTO PLANO."
  echo "    -> Resíduo do helper 'store'. Revogue os tokens e apague o arquivo."
fi

exit "$CHECK_FAILED"
