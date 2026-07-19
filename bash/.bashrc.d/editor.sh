#!/bin/bash

# Força Neovim como editor padrão, sobrescrevendo o default do sistema
# (Debian/Ubuntu setam EDITOR=/usr/bin/nano em
# /etc/profile.d/nano-default-editor.sh durante o login).
#
# Investigado em 2026-07-19: não há outras fontes injetando nano
# (MANPAGER não está definido, alternativas de sistema não apontam
# para nano, apt-config não define Editor, sudo não tem SUDO_EDITOR).
# Cobrir EDITOR/VISUAL/GIT_EDITOR é suficiente.

if command -v nvim &>/dev/null; then
  export EDITOR="nvim"
  export VISUAL="nvim"
  export GIT_EDITOR="nvim"
fi
