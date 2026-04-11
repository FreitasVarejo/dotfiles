#!/bin/bash

# Fix para Omega Character Issue no Yazi
# Aplica a variante Mono da JetBrains que tem melhor suporte a wide characters

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${BLUE}=== Fix para Omega Character Issue ===${NC}\n"

# Verificar dconf
if ! command -v dconf &>/dev/null; then
    log_error "dconf não encontrado"
    exit 1
fi

# UUID do perfil padrão
PROFILE_UUID="d698cc16d079f80d757fb42d68594767"
PROFILE_PATH="/org/gnome/Ptyxis/Profiles/$PROFILE_UUID"

log_info "Aplicando soluções para wide character rendering...\n"

# Solução 1: Variante Mono (recomendada)
log_info "Solução 1: Aplicando JetBrainsMonoNL Nerd Font Mono"
if fc-list | grep -iq "JetBrainsMonoNL Nerd Font Mono"; then
    dconf write "$PROFILE_PATH/monospace-font-name" "'JetBrainsMonoNL Nerd Font Mono 12'"
    log_success "Fonte mudada para JetBrainsMonoNL Nerd Font Mono"
else
    log_warn "JetBrainsMonoNL Nerd Font Mono não encontrada"
    log_info "Tentando JetBrainsMono Nerd Font Mono..."
    if fc-list | grep -iq "JetBrainsMono Nerd Font Mono"; then
        dconf write "$PROFILE_PATH/monospace-font-name" "'JetBrainsMono Nerd Font Mono 12'"
        log_success "Fonte mudada para JetBrainsMono Nerd Font Mono"
    else
        log_error "Nenhuma variante Mono encontrada!"
        exit 1
    fi
fi

# Solução 2: Garantir que ligaduras estão desabilitadas
log_info "Solução 2: Desabilitando ligaduras"
dconf write "$PROFILE_PATH/enable-ligatures" "false"
log_success "Ligaduras desabilitadas"

# Solução 3: Ajustar line spacing (workaround visual)
log_info "Solução 3: Ajustando line spacing"
# Nota: Ptyxis pode não ter essa opção em dconf, mas tentamos
dconf write "$PROFILE_PATH/line-spacing" "1.2" 2>/dev/null || log_warn "Line spacing: não suportado por dconf"

echo ""
echo -e "${BLUE}=== Configuração Aplicada ===${NC}\n"

# Mostrar configuração final
dconf dump "$PROFILE_PATH/" | grep -E "font|ligature|spacing"

echo ""
echo -e "${YELLOW}⚠️  Ação necessária:${NC}"
echo "1. Feche o GNOME Ptyxis completamente"
echo "2. Abra novamente"
echo "3. Teste no Yazi: yazi"
echo "4. Navegue com setas e verifique se o Omega desapareceu"
echo ""

log_success "Fix aplicado! Reinicie o terminal para ver as mudanças."
