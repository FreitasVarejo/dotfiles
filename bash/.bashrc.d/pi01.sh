#!/bin/bash

# pi01: o Claude e o que ele roda no host (npm, vitest) usam só os núcleos 0–2 e
# com prioridade baixa; o núcleo 3 é da produção. Subagentes compilando .NET em
# paralelo levavam o load do Pi ao teto e disputavam esse núcleo.
#
# Sem `command` na frente de `claude`: ele é builtin do bash, e o taskset executa
# o argumento como programa (`taskset: failed to execute command`). Dentro da
# função, `claude` chega ao binário porque o taskset resolve pelo PATH, não pelas
# funções do shell.

[[ ${HOSTNAME%%.*} == pi01 ]] || return 0

claude() { nice -n 10 taskset -c 0-2 claude "$@"; }
