#!/bin/bash
# shellcheck shell=bash
#
# Fonte única dos MCP servers expostos ao Claude Code. Sourced por
# hooks/check.sh (só usa as chaves/nomes) e hooks/setup.sh (usa nome + JSON
# para registrar). Este mapa É a lista do que faz parte do workflow: MCP
# registrado à mão numa máquina e ausente daqui é experimento local, sem
# healthcheck nem reprodução (ADR 0011 do projeto workflow-ia, no vault).
#
# Mantido como mapa bash (não um arquivo stowado) porque o Claude Code guarda a
# config MCP de escopo 'user' dentro de ~/.claude.json — arquivo com estado
# (histórico de sessão, trust de projeto) que não é seguro symlinkar inteiro.
#
# O $(gh auth token) no valor de [github] abaixo é literal de propósito (aspas
# simples): o headersHelper roda esse echo no MOMENTO DA CONEXÃO, e é lá que a
# substituição acontece — não aqui.
#
# Antes era $GITHUB_TOKEN, vindo de um `export` em ~/.bashrc.local. O problema
# não era o arquivo (0600, fora do stow, nunca commitado): era o `export`, que
# põe o segredo no ambiente de TODO processo filho, inclusive de todo agente.
# Um `env` num transcript bastava para vazá-lo. Como o headersHelper já é um
# comando de shell, ele pode simplesmente ir buscar o segredo — e o `gh` guarda
# o dele em ~/.config/gh/hosts.yml, lido sob demanda em vez de herdado.
#
# Não há MCP de Obsidian local: onde o vault está em disco, o agente lê e
# escreve os .md direto. O único MCP de Obsidian é o obsidian-web-mcp do pi01,
# para o claude.ai, que não tem disco (ADR 0008).
#
# 'ssh' aponta pro clone local em ~/mcp-servers/mcp-ssh (não é pacote npm
# publicado, foi clonado e buildado manualmente com `npm run build`). $HOME
# abaixo é literal de propósito (aspas duplas): expande aqui mesmo, no
# ambiente de quem roda o hook, já que o valor precisa virar path absoluto
# antes de ir pro JSON registrado no Claude Code.

declare -A CLAUDE_MCP_SERVERS
# shellcheck disable=SC2034  # consumido por hooks/check.sh e hooks/setup.sh via source
# shellcheck disable=SC2016  # $(gh auth token) é literal de propósito (expande no headersHelper)
CLAUDE_MCP_SERVERS=(
  [git]='{"type":"stdio","command":"npx","args":["-y","git-mcp"]}'
  [docker]='{"type":"stdio","command":"npx","args":["-y","docker-mcp"]}'
  [github]='{"type": "http", "url": "https://api.githubcopilot.com/mcp/", "headersHelper": "echo \"{\\\"Authorization\\\": \\\"Bearer $(gh auth token)\\\"}\""}'
  [ssh]="{\"type\":\"stdio\",\"command\":\"node\",\"args\":[\"$HOME/mcp-servers/mcp-ssh/dist/index.js\"]}"
)

# Onde o Claude Code guarda os MCP servers de escopo user.
#
# A comparação abaixo lê ESTE arquivo, e não a saída de `claude mcp list`, por
# dois motivos. O `list` imprime nome e status, nunca a CONFIGURAÇÃO — então
# quem só olhasse para ele conseguia responder "existe?" mas nunca "está em
# dia?", e era esse o buraco: o setup dizia "já registrado", seguia, e toda
# edição deste mapa ficava sem efeito até alguém remover o servidor na mão. O
# segundo motivo é que o `list` health-checka cada servidor, fazendo o setup
# depender de rede para responder uma pergunta puramente local.
CLAUDE_MCP_CONFIG="${CLAUDE_MCP_CONFIG:-$HOME/.claude.json}"

# mcp_plan — decide, por servidor, entre `ok`, `add`, `update` e `invalid`.
#
# Entrada: linhas "<nome>\t<json>" em stdin. Saída: "<nome>\t<veredito>".
# Compara os JSON já PARSEADOS, não os textos: a ordem das chaves no arquivo do
# Claude Code não é a do literal deste mapa, e comparar string acusaria
# diferença em toda execução.
mcp_plan() {
  # O script vai por `-c`, e NÃO por stdin. `python3 - <<EOF` faz do heredoc o
  # script, deixando o `sys.stdin` vazio e o pipe sem leitor — a função devolvia
  # silenciosamente nada, que é o pior modo de falhar aqui: "nenhum veredito"
  # se parece com "nada a fazer". stdin é o canal dos DADOS.
  # shellcheck disable=SC2016  # o script Python NÃO pode ser expandido pelo bash
  python3 -c '
import json, sys

try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        registered = json.load(fh).get("mcpServers") or {}
except (OSError, ValueError):
    # Sem config legível, todo servidor conta como ausente. É o lado seguro:
    # `add-json` de algo que já existe falha e vira aviso, enquanto o contrário
    # (concluir "em dia" sem ter lido nada) mascararia justamente o problema
    # que esta função existe para achar.
    registered = {}

for line in sys.stdin:
    name, _, raw = line.rstrip("\n").partition("\t")
    if not name:
        continue
    try:
        want = json.loads(raw)
    except ValueError:
        print("%s\tinvalid" % name)
        continue
    have = registered.get(name)
    if have is None:
        print("%s\tadd" % name)
    elif have == want:
        print("%s\tok" % name)
    else:
        print("%s\tupdate" % name)
' "$CLAUDE_MCP_CONFIG"
}

# Diretório de skills do pacote e o alvo do stow. Compartilhado pelos hooks
# para que "quais skills existem" tenha uma resposta só.
# shellcheck disable=SC2034  # consumido pelos hooks via source
CLAUDE_PKG_SKILLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.claude/skills" && pwd)"
# shellcheck disable=SC2034  # consumido pelos hooks via source
CLAUDE_HOME_SKILLS_DIR="$HOME/.claude/skills"

# skill_surfaces <skill-dir> -> imprime o valor de metadata.surfaces do SKILL.md
# ("code", "web" ou "code,web"; vazio se não declarado).
skill_surfaces() {
  sed -n '/^---$/,/^---$/p' "$1/SKILL.md" | sed -n 's/^  surfaces: *"\{0,1\}\([a-z,]*\)"\{0,1\}.*/\1/p' | head -n1
}
