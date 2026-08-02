#!/bin/bash
# Tmux shortcuts and utilities
# Usage: t [command] [args...]
# Examples:
#   t                    - list sessions
#   t ls / t l           - list sessions (alias)
#   t a session-name     - attach to session
#   t n session-name     - create new session
#   t k session-name     - kill session
#   t kall               - kill all sessions
#   t ssh session host [path] - new session, ssh into host (from ~/.ssh/config), optional cd
#   t rename old new     - rename session
#   t send cmd           - send command to active pane
#   t sp                 - split window horizontally
#   t vs                 - split window vertically
#   t sn window-name     - new window
#   t c                  - detach from session
#   t p                  - switch to previous session
#   t j                  - switch to next session

t() {
  local cmd="${1:-}"
  
  # No arguments: list sessions
  if [[ -z "$cmd" ]]; then
    tmux -u list-sessions 2>/dev/null || echo "No tmux sessions running"
    return $?
  fi
  
  case "$cmd" in
    # Attach to session
    a|attach)
      local session="${2:-}"
      if [[ -z "$session" ]]; then
        echo "Usage: t a <session-name>"
        return 1
      fi
      tmux -u attach-session -t "$session"
      ;;
    
    # New session
    n|new)
      local session="${2:-}"
      if [[ -z "$session" ]]; then
        echo "Usage: t n <session-name>"
        return 1
      fi
      tmux -u new-session -s "$session"
      ;;
    
    # Kill session
    k|kill)
      local session="${2:-}"
      if [[ -z "$session" ]]; then
        echo "Usage: t k <session-name>"
        return 1
      fi
      tmux -u kill-session -t "$session" && echo "Session '$session' killed"
      ;;
    
    # New session that SSHes into a host and optionally cds into a path
    ssh)
      local session="${2:-}"
      local host="${3:-}"
      local path="${4:-}"
      if [[ -z "$session" || -z "$host" ]]; then
        echo "Usage: t ssh <session-name> <host> [path]"
        return 1
      fi
      if ! awk -v h="$host" 'tolower($1) == "host" { for (i = 2; i <= NF; i++) if ($i == h) found=1 } END { exit !found }' ~/.ssh/config 2>/dev/null; then
        echo "Warning: host '$host' not found in ~/.ssh/config" >&2
      fi
      if [[ -n "$path" ]]; then
        tmux -u new-session -s "$session" ssh -t "$host" "cd '$path' && exec \$SHELL -il"
      else
        tmux -u new-session -s "$session" ssh -t "$host"
      fi
      ;;

    # Kill all sessions
    kall|kill-all)
      tmux -u kill-server
      echo "All tmux sessions killed"
      ;;
    
    # List sessions (alias for default behavior)
    ls|l|list)
      tmux -u list-sessions 2>/dev/null || echo "No tmux sessions running"
      ;;
    
    # List windows in session
    lw|list-windows)
      local session="${2:--}"
      tmux -u list-windows -t "$session"
      ;;
    
    # Rename session
    rename|mv)
      local old_name="${2:-}"
      local new_name="${3:-}"
      if [[ -z "$old_name" || -z "$new_name" ]]; then
        echo "Usage: t rename <old-name> <new-name>"
        return 1
      fi
      tmux -u rename-session -t "$old_name" "$new_name" && echo "Session renamed: $old_name → $new_name"
      ;;
    
    # Split window horizontally
    sp|split)
      tmux -u split-window -h
      ;;
    
    # Split window vertically
    vs|vsplit)
      tmux -u split-window -v
      ;;
    
    # New window in current session
    sn|new-window)
      local window_name="${2:-}"
      if [[ -n "$window_name" ]]; then
        tmux -u new-window -n "$window_name"
      else
        tmux -u new-window
      fi
      ;;
    
    # Detach from session
    c|detach)
      tmux -u detach-client
      echo "Detached from session"
      ;;
    
    # Previous session
    p|prev)
      tmux -u switch-client -p
      ;;
    
    # Next session
    j|next)
      tmux -u switch-client -n
      ;;
    
    # Send command to active pane
    send)
      shift  # Remove 'send'
      tmux -u send-keys -t "$(tmux -u display-message -p '#{session_name}')" "$@" Enter
      ;;
    
    # Show help
    h|help|--help|-h)
      cat << 'EOF'
Tmux shortcuts - Quick reference

Usage: t [command] [args...]

SESSÕES:
  (no args)         List all sessions
  ls / l            List all sessions
  a <session>       Attach to session
  n <session>       Create new session
  k <session>       Kill session
  kall              Kill all sessions
  ssh <session> <host> [path]  New session, SSH into host, cd into path
  rename <old> <new> Rename session
  p                 Switch to previous session
  j                 Switch to next session
  c                 Detach from current session

JANELAS:
  lw [session]      List windows in session
  sn [name]         Create new window (with optional name)
  sp                Split window horizontally
  vs                Split window vertically

OUTROS:
  send <cmd>        Send command to active pane
  h, help           Show this help

EXEMPLOS:
  t                       # List sessions
  t ls / t l              # List sessions
  t a dev                 # Attach to 'dev' session
  t n my-project          # Create new session 'my-project'
  t k old-session         # Kill 'old-session'
  t ssh pi01-work pi01 ~/projects/foo  # New session 'pi01-work', ssh pi01, cd to ~/projects/foo
  t rename dev development # Rename 'dev' to 'development'
  t sp                    # Split window horizontally
  t vs                    # Split window vertically
  t sn work               # Create new window named 'work'
  t p                     # Go to previous session
  t j                     # Go to next session
  t c                     # Detach from current session
EOF
      ;;
    
    # Fallback: pass through to tmux
    *)
      tmux -u "$@"
      ;;
  esac
}

export -f t
