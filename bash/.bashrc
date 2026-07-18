#!/bin/bash
# shellcheck shell=bash

# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Force UTF-8 locale (using C.UTF-8 for better compatibility)
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# User specific environment
if ! [[ "$PATH" =~ $HOME/.local/bin:$HOME/bin: ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc
# ---- CUDA -----------------------------------------
if [ -d "/usr/local/cuda" ]; then
    export CUDA_HOME=/usr/local/cuda
    export PATH=$CUDA_HOME/bin:$PATH
    export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
    # Força o nvcc a usar o GCC 13 se existir
    if [ -f "/usr/bin/g++-13" ]; then
        export NVCC_PREPEND_FLAGS="-ccbin /usr/bin/g++-13"
    fi
fi

# Lazy conda: carrega conda.sh na primeira chamada de `conda`,
# evitando o custo de inicialização (~150ms) em shells onde nunca é usado.
conda() {
    unfunction conda 2>/dev/null || unset -f conda
    if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
        . "$HOME/miniconda3/etc/profile.d/conda.sh"
    elif [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
        . "/opt/conda/etc/profile.d/conda.sh"
    fi
    command conda "$@"
}

if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
fi

if [ -d "$HOME/.dotnet/tools" ]; then
    export PATH=$PATH:$HOME/.dotnet/tools
fi

# opencode
if [ -d "$HOME/.opencode/bin" ]; then
    export PATH=$HOME/.opencode/bin:$PATH
fi

# Custom prompt - Modern style with hostname and window title
# export PS1='\[\e]0;\h\a\]\[\033[01;32m\]\h ➜  \[\033[01;34m\]\W\[\033[00m\] '

# Aliases para ls com cores e atalhos úteis
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias tmux='tmux -u'  # Force UTF-8 in tmux


# --- MODERN DOTFILES CONFIG ---
# Added by opencode on 2026-01-30

# Starship Prompt
if command -v starship &> /dev/null; then
    eval "$(starship init bash)"
fi

# Zoxide (Better cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init bash --cmd z)"
fi

# FZF (Fuzzy Finder): tenta o helper nativo primeiro, com fallback para
# paths comuns quando fzf --bash não existe (Ubuntu/Debian, Git for Windows, brew).
if command -v fzf &>/dev/null; then
    if ! eval "$(fzf --bash 2>/dev/null)"; then
        for _fzf_completion in \
            /usr/share/fzf/completion.bash \
            /usr/local/share/fzf/completion.bash \
            "$(brew --prefix 2>/dev/null)/opt/fzf/shell/completion.bash" \
            "$HOME/.fzf/shell/completion.bash"; do
            [ -f "$_fzf_completion" ] && . "$_fzf_completion" && break
        done
        for _fzf_keybind in \
            /usr/share/fzf/key-bindings.bash \
            /usr/local/share/fzf/key-bindings.bash \
            "$(brew --prefix 2>/dev/null)/opt/fzf/shell/key-bindings.bash" \
            "$HOME/.fzf/shell/key-bindings.bash"; do
            [ -f "$_fzf_keybind" ] && . "$_fzf_keybind" && break
        done
        unset _fzf_completion _fzf_keybind
    fi
fi

# Aliases for Modern Tools
if command -v bat &> /dev/null; then
    alias cat='bat'
fi

if command -v delta &> /dev/null; then
    alias diff='delta'
fi

if command -v lazygit &> /dev/null; then
    alias lg='lazygit'
fi

# Copilot CLI shortcuts (fallback para opencode --provider copilot).
# '!?' é expansão de histórico do bash; usamos eval para que o parser não
# tente validar '??' / '!?' como nomes em tempo de parse (algumas versões
# do bash falham em --rcfile com esses nomes).
if command -v github-copilot-cli &>/dev/null; then
    set +H
    eval '??() { github-copilot-cli suggest "$@"; }'
    eval '!?() { github-copilot-cli explain "$@"; }'
    set -H
elif command -v copilot &>/dev/null; then
    set +H
    eval '??() { copilot suggest "$@"; }'
    eval '!?() { copilot explain "$@"; }'
    set -H
fi

# Yazi: Wrapper para mudar de diretório ao sair
if command -v yazi &> /dev/null; then
    function y() {
        local tmp
        tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
        yazi "$@" --cwd-file="$tmp"
        local cwd
        cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd" || return
        rm -f -- "$tmp"
    }
fi

# --- VIM MODE ---
# Enable vi-style line editing
set -o vi
# Show vi mode in prompt (optional: shows [vi] when entering normal mode)
export PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}echo -ne '\033]0;${USER}@${HOSTNAME}\007'"

# Luacheck portável: respeita PATH se já existe, senão cai para ~/.luarocks/bin.
if command -v luacheck &>/dev/null; then
    luacheck() { command luacheck "$@"; }
elif [ -x "$HOME/.luarocks/bin/luacheck" ]; then
    luacheck() { "$HOME/.luarocks/bin/luacheck" "$@"; }
fi
