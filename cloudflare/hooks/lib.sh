#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2034  # as constantes são lidas por quem faz source deste arquivo
# Constantes do pacote 'cloudflare', lidas pelo setup.sh e pelo check.sh.

# A versão do `cf` fica fixa: a CLI está em beta, e um comando renomeado entre
# versões mudaria por baixo do agente sem aviso. As regras do Claude Code não
# dependem dela, porque casam pelo nome do wrapper. Trocar a versão é editar
# CF_VERSION e rodar ./setup.sh.
CF_VERSION="1.0.0-beta.14"
CF_NODE_MIN="22.18"
# Prefixo privado; o wrapper .local/bin/cf aponta para o mesmo caminho.
CF_PREFIX="$HOME/.local/lib/cf"
CF_BIN="$CF_PREFIX/node_modules/.bin/cf"
CF_TOKEN_DIR="$HOME/.config/cloudflare"

# cf_installed_version — versão do `cf` no prefixo, ou vazio.
cf_installed_version() {
  local pkg="$CF_PREFIX/node_modules/cf/package.json"
  [[ -f "$pkg" ]] || return 0
  sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$pkg" | head -n1
}

# node_at_least <min> — o `node` do PATH é >= min (major.minor)?
node_at_least() {
  local have
  have=$(node --version 2>/dev/null) || return 1
  have=${have#v}
  [[ "$(printf '%s\n%s\n' "$1" "$have" | sort -V | head -n1)" == "$1" ]]
}
