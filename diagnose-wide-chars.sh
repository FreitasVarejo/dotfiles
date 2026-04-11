#!/bin/bash

# Diagnóstico de Wide Character Issues no Yazi
# Detecta problemas com renderização de Nerd Fonts com cores invertidas

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${BLUE}=== Wide Character Rendering Diagnostic ===${NC}\n"

# 1. Verificar locale
log_info "Verificando locale..."
if [[ "$LANG" == *"UTF-8"* ]] || [[ "$LANG" == "C.UTF-8" ]]; then
    log_success "Locale UTF-8: $LANG"
else
    log_error "Locale não é UTF-8: $LANG"
    echo "  Fix: export LANG=C.UTF-8"
fi

# 2. Verificar wcwidth (caractere width)
log_info "Testando caracteres wide..."
echo ""
echo "  Teste 1: Símbolo simples"
printf "  \uf007 (user icon)\n"

echo "  Teste 2: Cor invertida (causa do problema)"
printf "  \e[7m\uf007\e[0m (com inverso)\n"

echo "  Teste 3: Símbolo com espaço extra"
printf "  \uf007  (com espaço depois)\n"

echo "  Teste 4: Símbolo sem espaço"
printf "  \uf007a\n"

# 3. Verificar font atual
log_info "Fonte configurada no terminal..."
dconf read /org/gnome/Ptyxis/Profiles/d698cc16d079f80d757fb42d68594767/monospace-font-name 2>/dev/null || echo "  (não conseguiu ler dconf)"

# 4. Verificar variantes disponíveis
log_info "Variantes de Nerd Font disponíveis..."
echo ""
fc-list | grep -i "jetbrain" | sed 's/.*: /  • /' | sed 's/,.*//g' | sort -u | head -10

# 5. Instruções específicas
echo ""
echo -e "${BLUE}=== Soluções para Omega Character Issue ===${NC}\n"

echo "Problema: Quando símbolos ficam com cores invertidas (seleção),"
echo "um caractere Omega (Ω) aparece atrás do símbolo.\n"

echo -e "${YELLOW}Soluções (em ordem de preferência):${NC}\n"

echo "1. Usar variante Mono da fonte (RECOMENDADO):"
echo "   dconf write /org/gnome/Ptyxis/Profiles/d698cc16d079f80d757fb42d68594767/monospace-font-name \"'JetBrainsMonoNL Nerd Font Mono 12'\""
echo "   → Mais compatível com wide character rendering"
echo ""

echo "2. Desabilitar ligaduras (se não fez ainda):"
echo "   dconf write /org/gnome/Ptyxis/Profiles/d698cc16d079f80d757fb42d68594767/enable-ligatures \"false\""
echo ""

echo "3. Usar fonte Hack Nerd Font (alternativa estável):"
echo "   dconf write /org/gnome/Ptyxis/Profiles/d698cc16d079f80d757fb42d68594767/monospace-font-name \"'Hack Nerd Font 12'\""
echo "   → Menos ícones, mas renderização mais estável"
echo ""

echo "4. Aumentar line spacing (workaround visual):"
echo "   • Preferences → Appearance"
echo "   • Aumentar 'Line Spacing' para 1.2 ou 1.5"
echo ""

echo -e "${BLUE}=== Próximos Passos ===${NC}\n"

echo "1. Escolha uma solução acima"
echo "2. Teste: Abra Yazi e navegue com seta para cima/baixo"
echo "3. Verifique se o Omega desapareceu nas linhas selecionadas"
echo "4. Se persistir, tente a próxima solução"
echo ""

log_success "Diagnóstico completo!"
