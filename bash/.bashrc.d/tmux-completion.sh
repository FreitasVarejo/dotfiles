#!/bin/bash
# Bash completion for tmux shortcuts (t command)
# Enables autocomplete for session names, commands, etc.

_t_completion() {
  local cur prev words cword
  COMPREPLY=()
  
  cur="${COMP_WORDS[cword]}"
  prev="${COMP_WORDS[cword-1]}"
  
  # Get list of tmux sessions (suppress errors if no sessions exist)
  local sessions
  sessions=$(tmux -u list-sessions -F "#{session_name}" 2>/dev/null)

  # Get list of hosts from ~/.ssh/config (skip wildcard patterns)
  local ssh_hosts
  ssh_hosts=$(awk 'tolower($1) == "host" { for (i = 2; i <= NF; i++) if ($i !~ /[*?]/) print $i }' ~/.ssh/config 2>/dev/null)

  # Determine context: first argument (command) or second+ argument (session/args)
  if [[ $cword -eq 1 ]]; then
    # First argument: complete commands
    local commands="a n k kall ls lw rename mv ssh send help h"
    COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
  else
    # Second+ argument: context-dependent completion
    local cmd="${COMP_WORDS[1]}"

    case "$cmd" in
      a|attach|n|new|k|kill|lw|list-windows)
        # These commands take session name as argument
        COMPREPLY=( $(compgen -W "$sessions" -- "$cur") )
        ;;
      rename|mv)
        # For rename, complete either old or new session name
        if [[ $cword -eq 2 ]]; then
          # Completing old session name
          COMPREPLY=( $(compgen -W "$sessions" -- "$cur") )
        else
          # Completing new session name - no completion
          COMPREPLY=()
        fi
        ;;
      ssh)
        # t ssh <session> <host> [path]: session has no completion, host comes from ~/.ssh/config
        if [[ $cword -eq 3 ]]; then
          COMPREPLY=( $(compgen -W "$ssh_hosts" -- "$cur") )
        else
          COMPREPLY=()
        fi
        ;;
      *)
        # For other commands, no specific completion
        COMPREPLY=()
        ;;
    esac
  fi
  
  return 0
}

# Register completion for 't' command
complete -o bashdefault -o default -o nospace -F _t_completion t
