#!/bin/bash

# React + Vite + TypeScript Setup Script
# Este script configura um novo projeto React com todas as ferramentas necessárias

set -e

PROJECT_NAME="${1:-.}"
NVIM_CONFIG_DIR="$HOME/.config/nvim"

echo "📦 Setup React + Vite + TypeScript + Tailwind"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$PROJECT_NAME" != "." ]; then
    echo "📁 Criando projeto: $PROJECT_NAME"
    npm create vite@latest "$PROJECT_NAME" -- --template react-ts
    cd "$PROJECT_NAME"
fi

echo "📥 Instalando dependências..."
npm install

echo "🔧 Instalando ferramentas de desenvolvimento..."
npm install -D \
    eslint \
    @typescript-eslint/eslint-plugin \
    @typescript-eslint/parser \
    eslint-plugin-react \
    eslint-plugin-react-hooks \
    prettier \
    eslint-config-prettier

echo "📋 Copiando configurações..."

# Copiar .eslintrc.json
if [ -f "$NVIM_CONFIG_DIR/.eslintrc.json" ]; then
    cp "$NVIM_CONFIG_DIR/.eslintrc.json" .
    echo "✅ .eslintrc.json copiado"
fi

# Copiar .prettierrc.json
if [ -f "$NVIM_CONFIG_DIR/.prettierrc.json" ]; then
    cp "$NVIM_CONFIG_DIR/.prettierrc.json" .
    echo "✅ .prettierrc.json copiado"
fi

# Copiar tsconfig.json template
if [ -f "$NVIM_CONFIG_DIR/tsconfig.template.json" ]; then
    if [ ! -f "tsconfig.json" ]; then
        cp "$NVIM_CONFIG_DIR/tsconfig.template.json" tsconfig.json
        echo "✅ tsconfig.json copiado"
    fi
fi

echo ""
echo "✨ Setup concluído!"
echo ""
echo "📝 Próximos passos:"
echo "1. Abrir o projeto no Neovim: nvim ."
echo "2. Verificar LSP: :LspInfo"
echo "3. Testar snippets: rfc<Tab>"
echo "4. Formatar: <leader>fm"
echo "5. ESLint fix: <leader>el"
echo ""
