#!/bin/bash

# Node.js toolchain via NVM com lazy-load.
# O startup do nvm.sh custa ~300ms; só pagamos quando o usuário
# invoca nvm, node, npm, npx, pnpm ou corepack pela primeira vez.

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

_nvm_lazy_load() {
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    if command -v nvm &>/dev/null; then
        nvm use default 2>/dev/null || nvm use 22 2>/dev/null || true
        corepack enable 2>/dev/null || true
    fi
    for _cmd in nvm node npm npx pnpm corepack; do
        unfunction "$_cmd" 2>/dev/null || unset -f "$_cmd"
    done
    unset -f _nvm_lazy_load
}

_nvm_wrap() {
    _nvm_lazy_load
    command "$@"
}

for _cmd in nvm node npm npx pnpm corepack; do
    eval "$_cmd() { _nvm_wrap $_cmd \"\$@\"; }"
done
unset _cmd
