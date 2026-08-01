#!/bin/bash
# shellcheck shell=bash
#
# Orquestrador de healthcheck. Descobre os hooks de check por pacote
# (<pkg>/hooks/check.sh), roda cada um como subprocesso READ-ONLY e agrega os
# exit codes. Adicionar um pacote = criar <pkg>/hooks/check.sh, sem tocar aqui.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"

echo "=== Dotfiles Healthcheck ==="
echo "Verificando se as ferramentas necessárias estão instaladas..."
echo "(gerenciador de pacotes detectado: ${PM_INSTALL})"
echo ""

ALL_GOOD=true

for hook in "$DOTFILES_DIR"/*/hooks/check.sh; do
  [[ -f "$hook" ]] || continue
  if ! bash "$hook"; then
    ALL_GOOD=false
  fi
  echo ""
done

if [ "$ALL_GOOD" = true ]; then
  echo -e "${GREEN} Tudo parece estar correto! Você pode rodar ./setup.sh agora.${NC}"
else
  echo -e "${RED} Faltam dependências.${NC}"
  echo "Instale as ferramentas listadas como [MISSING] acima antes de rodar ./setup.sh para a melhor experiência."
fi
