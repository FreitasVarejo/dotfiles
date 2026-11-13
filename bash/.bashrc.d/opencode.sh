#!/bin/bash
# opencode dentro do tmux: sem -s/-c, gera o id da conversa e a abre com `-s`
# (o opencode 2.x cria a conversa se o id não existe; só exige o prefixo `ses_`),
# para o snapshot do tmux saber qual conversa reabrir (contrato @revive, em
# tmux/scripts/snapshot). É função, e não script em ~/.local/bin, porque o
# PATH pode pôr ~/.npm-global/bin antes dele.

_opencode_new_id() {
  # `ses_` + 12 hex (tempo invertido em 48 bits: a mais nova ordena primeiro,
  # como as do opencode) + 14 alfanuméricos.
  local ms=$(($(date +%s%3N) * 4096)) rnd
  rnd=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 14)
  printf 'ses_%012x%s' $(((~ms) & 0xffffffffffff)) "$rnd"
}

opencode() {
  local revive="$HOME/.config/tmux/scripts/revive" id="" skip=0 prev="" arg rc
  if [[ -z "${TMUX_PANE:-}" || ! -x "$revive" ]]; then
    command opencode "$@"
    return $?
  fi
  # Subcomando (run, session, auth...): primeiro argumento que não é flag nem pasta.
  if [[ -n "${1:-}" && "$1" != -* && ! -d "$1" ]]; then
    command opencode "$@"
    return $?
  fi
  for arg in "$@"; do
    case "$arg" in
      -c | --continue | -h | --help | -v | --version | --wizard | --completions) skip=1 ;;
      --session=*) id="${arg#--session=}" ;;
    esac
    [[ "$prev" == -s || "$prev" == --session ]] && id="$arg"
    prev="$arg"
  done
  if ((skip)); then
    command opencode "$@"
    return $?
  fi
  if [[ -n "$id" ]]; then
    "$revive" set "opencode -s $id"
    command opencode "$@"
  else
    id=$(_opencode_new_id)
    "$revive" set "opencode -s $id"
    command opencode -s "$id" "$@"
  fi
  rc=$?
  "$revive" clear
  return $rc
}
