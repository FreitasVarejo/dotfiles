#!/bin/bash
# Tmux shortcuts and utilities
# Usage: t [command] [args...]
# Examples:
#   t                    - list sessions
#   t a session-name     - attach to session
#   t n session-name     - create new session
#   t k session-name     - kill session
#   t kall               - kill all sessions
#   t rename old new     - rename session
#   t send cmd           - send command to active pane

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
    
    # Kill all sessions
    kall|kill-all)
      tmux -u kill-server
      echo "All tmux sessions killed"
      ;;
    
    # List sessions (alias for default behavior)
    ls|list)
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

Commands:
  (no args)         List all sessions
  a <session>       Attach to session
  n <session>       Create new session
  k <session>       Kill session
  kall              Kill all sessions
  ls                List sessions
  lw [session]      List windows in session
  rename <old> <new> Rename session
  send <cmd>        Send command to active pane
  h, help           Show this help

Examples:
  t                       # List sessions
  t a dev                 # Attach to 'dev' session
  t n my-project          # Create new session 'my-project'
  t k old-session         # Kill 'old-session'
  t rename dev development # Rename 'dev' to 'development'
  t lw dev                # List windows in 'dev' session
EOF
      ;;
    
    # Fallback: pass through to tmux
    *)
      tmux -u "$@"
      ;;
  esac
}

export -f t
