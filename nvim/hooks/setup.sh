#!/bin/bash
# shellcheck shell=bash
# Setup do pacote 'nvim': aquece o lazy.nvim (instala plugin que falta) e
# sobe o limite de inotify que o Roslyn esgota numa solution grande.
#
# O clone do freitask morava aqui enquanto o Neovim o carregava como plugin;
# desde que o picker virou a TUI, quem precisa do clone é a CLI, e ele mora no
# hook do pacote 'vault'.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"

log_info "--- Neovim warmup (lazy.nvim) ---"
# Estava no check.sh, que precisa ser read-only. `install` e não `sync`: só
# baixa o que falta e não reescreve o lazy-lock.json do repo.
if command -v nvim &>/dev/null; then
  if timeout 300 nvim --headless "+Lazy! install" +qa &>/dev/null; then
    log_success "Plugins do lazy.nvim instalados"
  else
    log_warn "Warmup do lazy.nvim falhou ou excedeu 300s"
    echo "    -> Rode à mão para ver o erro: nvim --headless '+Lazy! install' +qa"
  fi
else
  log_info "Warmup pulado (nvim ausente)."
fi

log_info "--- Limite de inotify (Roslyn) ---"
# O limite sobe para o Roslyn não falhar ao carregar uma solution de dezenas de
# projetos se algum watcher escapar; o Neovim continua com filewatching = "off"
# e avisa do arquivo no save (nvim/lua/plugins/lang/dotnet.lua).
INOTIFY_CONF=/etc/sysctl.d/99-dotfiles-inotify.conf
INOTIFY_INSTANCES=1024
INOTIFY_WATCHES=524288
if [[ ! -r /proc/sys/fs/inotify/max_user_instances ]]; then
  log_info "Pulado (sem inotify neste sistema)."
elif (($(cat /proc/sys/fs/inotify/max_user_instances) >= INOTIFY_INSTANCES)) &&
  (($(cat /proc/sys/fs/inotify/max_user_watches) >= INOTIFY_WATCHES)); then
  log_success "inotify já em instances >= $INOTIFY_INSTANCES, watches >= $INOTIFY_WATCHES"
else
  # Sem terminal, sudo não pode pedir senha: não trava o setup.
  SUDO=(sudo)
  [[ -t 0 ]] || SUDO=(sudo -n)
  if printf 'fs.inotify.max_user_instances = %s\nfs.inotify.max_user_watches = %s\n' \
    "$INOTIFY_INSTANCES" "$INOTIFY_WATCHES" | "${SUDO[@]}" tee "$INOTIFY_CONF" >/dev/null &&
    "${SUDO[@]}" sysctl -q --load "$INOTIFY_CONF"; then
    log_success "inotify: $INOTIFY_CONF aplicado"
  else
    log_warn "Não deu para escrever $INOTIFY_CONF"
    echo "    -> Rode ./setup.sh num terminal (o sudo pede a senha)"
  fi
fi
