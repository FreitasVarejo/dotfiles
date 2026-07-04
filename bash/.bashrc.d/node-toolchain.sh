#!/bin/bash

# Node.js toolchain via NVM

if [ -d "$HOME/.nvm" ]; then
    export NVM_DIR="$HOME/.nvm"

    if [ -s "$NVM_DIR/nvm.sh" ]; then
        . "$NVM_DIR/nvm.sh"
    fi

    if command -v node &>/dev/null; then
        NODE_BIN=$(dirname "$(command -v node)")
        if [ -d "$NODE_BIN" ]; then
            export PATH="$NODE_BIN:$PATH"
        fi
    fi
fi