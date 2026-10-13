#!/bin/bash
# shellcheck shell=bash
# Checks READ-ONLY do pacote 'cloudflare': Node, a CLI `cf` na versão fixa,
# os wrappers `cf`/`cf-write` à frente no PATH, os dois tokens do agente e o id
# da conta. Só cobra onde existe o diretório dos tokens: máquina sem ele (o WSL
# do trabalho) não opera a Cloudflare, e o check sai sem cobrar nada. Com o
# diretório, token ou id ausente é aviso, porque o wrapper recusa rodar sem eles.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log_info "--- Cloudflare (cf) ---"

if [[ ! -d "$CF_TOKEN_DIR" ]]; then
  log_optional "${CF_TOKEN_DIR/#$HOME/\~} ausente: esta máquina não opera a Cloudflare"
  echo "    -> Para operar: install -D -m 600 /dev/stdin ${CF_TOKEN_DIR/#$HOME/\~}/read-token   (cole o token, Ctrl-D), depois ~/dotfiles/setup.sh"
  exit 0
fi

# 1. Node ----------------------------------------------------------------------
if node_at_least "$CF_NODE_MIN"; then
  log_success "node $(node --version) (cf pede >= $CF_NODE_MIN)"
else
  log_missing "cf pede Node >= $CF_NODE_MIN (no PATH: $(node --version 2>/dev/null || echo nenhum))"
  echo "    -> $PM_INSTALL nodejs"
  fail_check
fi

# 2. A CLI no prefixo privado ----------------------------------------------------
HAVE=$(cf_installed_version)
if [[ "$HAVE" == "$CF_VERSION" && -x "$CF_BIN" ]]; then
  log_success "cf $CF_VERSION em ${CF_PREFIX/#$HOME/\~}"
elif [[ -n "$HAVE" ]]; then
  log_missing "cf $HAVE em ${CF_PREFIX/#$HOME/\~}, o repo fixa $CF_VERSION"
  echo "    -> ~/dotfiles/setup.sh"
  fail_check
else
  log_missing "cf não instalado em ${CF_PREFIX/#$HOME/\~}"
  echo "    -> ~/dotfiles/setup.sh"
  fail_check
fi

# 3. Os wrappers são os primeiros no PATH ----------------------------------------
# Outro `cf` na frente rodaria sem o token escolhido aqui, e a separação entre
# leitura e escrita deixaria de valer.
for NAME in cf cf-write; do
  FOUND=$(command -v "$NAME" || true)
  if [[ -n "$FOUND" && "$(readlink -f "$FOUND")" == "$DOTFILES_DIR/cloudflare/"* ]]; then
    log_success "$NAME -> wrapper do dotfiles (${FOUND/#$HOME/\~})"
  elif [[ -n "$FOUND" ]]; then
    log_error "$NAME no PATH não é o wrapper do dotfiles: $FOUND"
    echo "    -> Remova ou tire do PATH; o cf de verdade mora em ${CF_PREFIX/#$HOME/\~}"
    fail_check
  else
    log_missing "$NAME não está no PATH"
    echo "    -> ~/dotfiles/setup.sh (stow do pacote cloudflare)"
    fail_check
  fi
done

# 4. Tokens do agente ------------------------------------------------------------
declare -A TOKEN_OF=([cf]=read-token [cf-write]=write-token)
for NAME in cf cf-write; do
  FILE="$CF_TOKEN_DIR/${TOKEN_OF[$NAME]}"
  if [[ ! -s "$FILE" ]]; then
    log_warn "${FILE/#$HOME/\~} ausente (sem ele, o \`$NAME\` recusa rodar)"
    echo "    -> install -D -m 600 /dev/stdin ${FILE/#$HOME/\~}   (cole o token, Ctrl-D)"
  elif [[ "$(stat -c %a "$FILE")" != "600" ]]; then
    log_warn "${FILE/#$HOME/\~} com modo $(stat -c %a "$FILE"), esperado 600"
    echo "    -> chmod 600 ${FILE/#$HOME/\~}"
  else
    log_success "${FILE/#$HOME/\~} presente (600)"
  fi
done

# 5. Id da conta -----------------------------------------------------------------
FILE="$CF_TOKEN_DIR/account-id"
if [[ ! -s "$FILE" ]]; then
  log_warn "${FILE/#$HOME/\~} ausente (sem ele, \`cf\` e \`cf-write\` recusam rodar)"
  echo "    -> echo <id> > ${FILE/#$HOME/\~}   (o trecho depois de dash.cloudflare.com/ na URL do painel)"
elif [[ ! "$(<"$FILE")" =~ ^[0-9a-f]{32}$ ]]; then
  log_warn "${FILE/#$HOME/\~} não tem cara de id de conta (32 caracteres hexadecimais)"
else
  log_success "${FILE/#$HOME/\~} presente"
fi

exit "${CHECK_FAILED:-0}"
