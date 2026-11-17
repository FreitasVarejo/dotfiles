#!/bin/bash
# opencode dentro do tmux: um pane, uma conversa, um servidor.
#
# Sem -s/-c, gera o id da conversa e a abre com `-s` (o opencode 2.x cria a
# conversa se o id não existe; só exige o prefixo `ses_`), para o snapshot do
# tmux saber qual conversa reabrir (contrato @revive, em tmux/scripts/snapshot).
# Vale para a tela cheia e para `opencode mini`.
#
# Acrescenta `--standalone`: o TUI sobe o servidor dele como filho, e o ctrl+c
# (ou fechar o pane) o leva junto. Sem a flag, a conversa roda no serviço de
# fundo (`opencode serve --service`), que sobrevive ao pane. O @revive leva o
# comando inteiro, com a flag.
#
# Passa direto, sem @revive: subcomandos (run, session, auth...), -c/--continue,
# --fork (o id novo é do opencode), --server (servidor de outro) e a ajuda.
#
# É função, e não script em ~/.local/bin, porque o PATH pode pôr
# ~/.npm-global/bin antes dele.

_opencode_new_id() {
  # `ses_` + 12 hex (tempo invertido em 48 bits: a mais nova ordena primeiro,
  # como as do opencode) + 14 alfanuméricos.
  local ms=$(($(date +%s%3N) * 4096)) rnd
  rnd=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 14)
  printf 'ses_%012x%s' $(((~ms) & 0xffffffffffff)) "$rnd"
}

opencode() {
  local revive="$HOME/.config/tmux/scripts/revive" id="" skip=0 prev="" arg rc
  local mode="" rest=()
  if [[ -z "${TMUX_PANE:-}" || ! -x "$revive" ]]; then
    command opencode "$@"
    return $?
  fi
  if [[ "${1:-}" == mini ]]; then
    mode=mini
    shift
  elif [[ -n "${1:-}" && "$1" != -* && ! -d "$1" ]]; then
    # Subcomando (run, session, auth...): primeiro argumento que não é flag nem pasta.
    command opencode "$@"
    return $?
  fi
  for arg in "$@"; do
    case "$arg" in
      -c | --continue | --fork | --server | --server=* | -h | --help | -v | --version | --wizard | --completions) skip=1 ;;
      --session=*) id="${arg#--session=}" ;;
    esac
    [[ "$prev" == -s || "$prev" == --session ]] && id="$arg"
    prev="$arg"
    # --standalone é do wrapper: o que o dono passou não se repete.
    [[ "$arg" == --standalone ]] || rest+=("$arg")
  done
  if ((skip)); then
    command opencode ${mode:+"$mode"} "$@"
    return $?
  fi
  if [[ -n "$id" ]]; then
    "$revive" set "opencode${mode:+ $mode} --standalone -s $id"
    command opencode ${mode:+"$mode"} --standalone "${rest[@]}"
  else
    id=$(_opencode_new_id)
    "$revive" set "opencode${mode:+ $mode} --standalone -s $id"
    command opencode ${mode:+"$mode"} --standalone -s "$id" "${rest[@]}"
  fi
  rc=$?
  "$revive" clear
  return $rc
}
