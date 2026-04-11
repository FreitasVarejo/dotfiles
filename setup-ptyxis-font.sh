#!/bin/bash

# Configure Nerd Fonts for GNOME Ptyxis Terminal
# Usage: ./setup-ptyxis-font.sh

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${BLUE}=== Configurando Nerd Fonts para GNOME Ptyxis ===${NC}\n"

# 1. Verificar se dconf está disponível
if ! command -v dconf &>/dev/null; then
    log_error "dconf não encontrado. Instale dconf para configurar o GNOME Ptyxis."
    exit 1
fi

# 2. Verificar se as Nerd Fonts estão instaladas
log_info "Verificando Nerd Fonts instaladas..."
JETBRAINS_COUNT=$(fc-list | grep -i "jetbrain" | wc -l)
if [[ $JETBRAINS_COUNT -eq 0 ]]; then
    log_error "JetBrains Nerd Fonts não encontradas!"
    exit 1
fi
log_success "JetBrains Nerd Font detectada ($JETBRAINS_COUNT variantes)"

# 3. Listar fontes disponíveis
log_info "Fontes Nerd Font disponíveis:"
fc-list | grep -i "jetbrain" | sed 's/.*: /  • /' | head -5
echo ""

# 4. Obter o UUID do perfil padrão do Ptyxis
log_info "Obtendo configurações do GNOME Ptyxis..."
PROFILE_UUID=$(dconf read /org/gnome/Ptyxis/default-profile-uuid | tr -d "'")

if [[ -z "$PROFILE_UUID" ]]; then
    log_error "Não foi possível obter o UUID do perfil padrão do Ptyxis."
    exit 1
fi

log_success "Perfil padrão UUID: $PROFILE_UUID"

# 5. Configurar a fonte para JetBrains Mono Nerd Font
log_info "Configurando JetBrains Mono Nerd Font..."

# Opções de fonte (em ordem de preferência)
FONTS=(
    "JetBrainsMono Nerd Font"
    "JetBrainsMonoNL Nerd Font"
    "JetBrainsMono Nerd Font Mono"
)

SELECTED_FONT=""
for font in "${FONTS[@]}"; do
    if fc-list | grep -iq "$font"; then
        SELECTED_FONT="$font"
        log_success "Usando: $SELECTED_FONT"
        break
    fi
done

if [[ -z "$SELECTED_FONT" ]]; then
    log_error "Nenhuma variante adequada de JetBrains Mono Nerd Font encontrada"
    exit 1
fi

# 6. Aplicar as configurações via dconf
PROFILE_PATH="/org/gnome/Ptyxis/Profiles/$PROFILE_UUID"

# Desabilitar fonte do sistema para usar fonte customizada
dconf write "$PROFILE_PATH/use-system-font" "false" || log_warn "Erro ao desabilitar system font"

# Configurar a família de fonte (se o dconf suportar)
dconf write "$PROFILE_PATH/monospace-font-name" "'$SELECTED_FONT 12'" || log_warn "Erro ao configurar font-family"

# Ativar suporte a símbolos (desabilitar ligaduras se houver)
dconf write "$PROFILE_PATH/enable-ligatures" "false" 2>/dev/null || log_warn "Ligaduras: opção não disponível"

log_success "Configurações aplicadas ao Ptyxis!"

# 7. Verificar configuração
echo ""
log_info "Configuração atual do Ptyxis:"
dconf dump "$PROFILE_PATH/" 2>/dev/null | grep -E "font|ligature" || echo "  (sem filtros aplicáveis)"

# 8. Instruções finais
echo ""
echo -e "${BLUE}=== Próximos Passos ===${NC}"
echo "1. Feche e abra novamente o GNOME Ptyxis para aplicar as mudanças"
echo "2. As fontes podem ser ajustadas via:"
echo "   → Preferences (⚙️) → Appearance → Font"
echo "3. Teste a renderização com:"
echo "   printf '\\uf007 \\uf086 \\uf1d8 \\uf0e0\\n'  # Ícones Nerd Font"
echo ""
log_success "Configuração concluída!"
