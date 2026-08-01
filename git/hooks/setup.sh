#!/bin/bash
# shellcheck shell=bash
# Setup do pacote 'git': configura a identidade global se ainda não existir.
# Interativo (pergunta nome/email). Mutação de estado fica AQUI, não no check.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"

git_name=$(git config --global user.name 2>/dev/null)
git_email=$(git config --global user.email 2>/dev/null)

if [ -n "$git_name" ] && [ -n "$git_email" ]; then
  log_success "Git identity já configurada: $git_name <$git_email>"
  exit 0
fi

log_warn "Git identity não configurada."
echo "    Digite seu nome completo (sem acentos ou caracteres especiais, ex: sem 'ç'):"
read -r full_name
echo "    Digite seu email (o mesmo da sua conta GitHub):"
read -r email

if [ -z "$full_name" ] || [ -z "$email" ]; then
  log_warn "Nome ou email vazio — pulando configuração da identidade."
  exit 0
fi

git config --global user.name "$full_name"
git config --global user.email "$email"
log_success "Git identity configurada: $full_name <$email>"
