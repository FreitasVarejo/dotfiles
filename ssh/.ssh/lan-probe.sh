#!/bin/bash
# shellcheck shell=bash
#
# Decide se um host está alcançável na LAN *de verdade*, para uso em
# `Match host <x> exec` no ~/.ssh/config.local.
#
# Uso: lan-probe.sh <ip> <arquivo-com-a-chave-ed25519-esperada>
#
# Por que não um `ping`: ICMP prova que ALGUÉM tem aquele IP, não que seja o
# host certo. Numa rede visitante que também usa 192.168.15.0/24, o .4 é outro
# aparelho — o ping responde, o ssh vai para a máquina errada e leva
# "connection refused" (ou, pior, conecta em outra coisa). Aqui a checagem é de
# identidade: só passa se a porta 22 apresentar a chave de host esperada.
#
# Genérico de propósito: IP e chave vêm por argumento e ficam em
# ~/.ssh/config.local / ~/.ssh/*.hostkey, que não são versionados.

ip="$1"
keyfile="$2"

[ -n "$ip" ] && [ -r "$keyfile" ] || exit 1

expected=$(tr -d '[:space:]' < "$keyfile")
[ -n "$expected" ] || exit 1

# -T 1: um segundo de teto. O custo só é pago na PRIMEIRA conexão de cada
# janela de ControlPersist; as seguintes reusam o socket master.
actual=$(ssh-keyscan -T 1 -t ed25519 "$ip" 2>/dev/null | grep -v '^#' | awk '{print $3}' | head -1)

[ -n "$actual" ] && [ "$actual" = "$expected" ]
