#!/bin/bash

# Node.js toolchain via NVM com lazy-load.
# O startup do nvm.sh custa ~300ms; só pagamos quando o usuário
# invoca nvm, node, npm, npx, pnpm ou corepack pela primeira vez.

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

# Sem '_' na frente de propósito: o snapshot de shell do Claude Code descarta
# funções com '_', e os wrappers abaixo ficariam chamando um helper que sumiu.
dotfiles_nvm_load() {
    # Remove nossos wrappers ANTES de carregar nvm.sh, porque nvm.sh
    # define 'nvm' como função e nossos unset no fim apagariam ela.
    for _cmd in nvm node npm npx pnpm corepack; do
        unset -f "$_cmd" 2>/dev/null || true
    done

    # shellcheck source=/dev/null  # instalado pelo nvm, fora do repo
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    if type nvm &>/dev/null; then
        nvm use default 2>/dev/null || nvm use 22 2>/dev/null || true
        corepack enable 2>/dev/null || true
    fi

    unset -f dotfiles_nvm_load
}

for _cmd in nvm node npm npx pnpm corepack; do
    eval "$_cmd() { dotfiles_nvm_load; $_cmd \"\$@\"; }"
done
unset _cmd
