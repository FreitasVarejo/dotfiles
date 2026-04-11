#!/bin/bash

# Font Health Check for Fedora 41 + Nerd Fonts
# Usage: ./healthcheck-fonts.sh

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${BLUE}=== Nerd Fonts Health Check ===${NC}\n"

# 1. Check Font Cache
log_info "Checking font cache..."
if fc-cache -v ~/.local/share/fonts/ &>/dev/null; then
    log_success "Font cache is valid"
else
    log_error "Font cache rebuild failed"
    exit 1
fi

# 2. Count JetBrains Fonts
JETBRAINS_COUNT=$(fc-list | grep -i "jetbrain" | wc -l)
log_info "JetBrains Nerd Fonts found: $JETBRAINS_COUNT"
if [[ $JETBRAINS_COUNT -gt 0 ]]; then
    log_success "JetBrains fonts detected"
else
    log_error "JetBrains Nerd Fonts not found!"
    exit 1
fi

# 3. Check for corrupted fonts
log_info "Checking for corrupted font files..."
CORRUPTED=0
for font in ~/.local/share/fonts/JetBrainsMono/*.ttf; do
    if ! fc-query -f '%{family}\n' "$font" &>/dev/null; then
        log_warn "Corrupted: $(basename "$font")"
        ((CORRUPTED++))
    fi
done

if [[ $CORRUPTED -eq 0 ]]; then
    log_success "No corrupted fonts detected"
else
    log_warn "Found $CORRUPTED potentially corrupted fonts"
fi

# 4. Check locale
log_info "Checking locale settings..."
if [[ "$LANG" == *"UTF-8"* ]] || [[ "$LANG" == "C.UTF-8" ]]; then
    log_success "Locale is UTF-8 compatible: $LANG"
else
    log_warn "Locale might have issues: $LANG"
fi

# 5. Check terminal support
log_info "Checking terminal support..."
if [[ "$TERM" == *"256color"* ]] || [[ "$TERM" == *"truecolor"* ]]; then
    log_success "Terminal supports colors: $TERM"
else
    log_warn "Terminal color support might be limited: $TERM"
fi

# 6. Test Nerd Font symbols
log_info "Testing Nerd Font symbols rendering..."
SYMBOLS=$(printf '\uf007 \uf086 \uf1d8 \uf0e0')
echo "  Symbols: $SYMBOLS"

echo -e "\n${GREEN}=== Health Check Complete ===${NC}"
