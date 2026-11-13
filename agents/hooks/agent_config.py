#!/usr/bin/env python3
"""Compara e mescla a config dos agentes (Claude Code, Cursor, OpenCode) com o repo.

Chamado pelos hooks do pacote 'agents' (lib.sh). Regras que valem para tudo:

- Só ACRESCENTA ou ATUALIZA o que o repo declara. MCP ou regra de permissão que
  só existe na máquina é experimento local (ADR 0011) e fica onde está.
- Os comandos `*-plan` e `mcp-registered` são só leitura (o check.sh usa); só
  `*-apply` escreve.
- Escrita é atômica (tmp + rename no mesmo diretório) e só acontece quando há
  diferença, para que rodar o setup duas vezes não reescreva nada.
- Arquivo AUSENTE é vazio; arquivo PRESENTE mas ilegível é erro, nunca vazio.
  Tratá-lo como vazio faria o apply gravar por cima e apagar a config de quem
  só errou uma vírgula — e faria o plan dizer "em dia" sobre o que nem leu.

Saída 2 = arquivo do REPO inválido (mcp/*.json, deny.json, settings/*.json,
travas/travas.json, opencode/config.json, opencode/cli.json, subagents/*.md,
skills/*/SKILL.md);
saída 3 = arquivo do AGENTE ilegível (opencode.json, cli.json, modelos.json, arquivo gerado).
A mensagem vai para stderr.

Uso:
  agent_config.py mcp-servers <mcp-dir>                    (nome\\tjson-compacto)
  agent_config.py mcp-registered <arquivo>                 (um nome por linha)
  agent_config.py mcp-plan  <claude|cursor> <arquivo> <mcp-dir>
  agent_config.py mcp-apply cursor <arquivo> <mcp-dir>
  agent_config.py deny-plan  <claude|cursor> <arquivo> <deny.json>
  agent_config.py deny-apply <claude|cursor> <arquivo> <deny.json>
  agent_config.py settings-plan  claude <arquivo> <fragmento.json>  (chave\\tadd|update)
  agent_config.py settings-apply claude <arquivo> <fragmento.json>
  agent_config.py hooks-plan  claude <arquivo> <travas.json>   (evento\\tadd|update|remove)
  agent_config.py hooks-apply claude <arquivo> <travas.json>
  agent_config.py opencode-plan  <dir-de-config> <pacote-agents> <maquina>   (chave\\tadd|update|remove|skip|blocked)
  agent_config.py opencode-apply <dir-de-config> <pacote-agents> <maquina>

O deny.json tem as categorias read, shell, edit e agent. `agent` (nomes de subagente)
só existe no Claude Code, onde vira `Agent(<nome>)`; no Cursor e no OpenCode é pulada.

O alvo `opencode` (ADR 0046) mescla share, instructions, permissions e policies no
opencode.json do diretório de config, mescla plugins e keybinds (de opencode/cli.json,
quando existe) no cli.json do TUI dele e GERA agents/*.md (de subagents/) e commands/*.md
(das skills) nele. Só age onde há OpenCode 2.x: quem decide é o lib.sh, não este script.
"""

import copy
import glob
import json
import os
import re
import sys
import tempfile

# Chaves que só o Claude Code entende. Servidor que depende de uma delas não vai
# para o Cursor: lá ele subiria sem o header e falharia com 401 em silêncio.
CLAUDE_ONLY_KEYS = {"headersHelper"}


class ConfigError(Exception):
    def __init__(self, code, msg):
        super().__init__(msg)
        self.code = code


def repo_error(msg):
    return ConfigError(2, msg)


def agent_error(msg):
    return ConfigError(3, msg)


def load_agent(path):
    """JSON do arquivo do agente: {} se não existe, erro se existe e não se lê."""
    if not os.path.lexists(path):
        return {}
    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError) as exc:
        raise agent_error("%s ilegível (%s); corrija à mão, nada foi gravado" % (path, exc))
    if not isinstance(data, dict):
        raise agent_error("%s não é um objeto JSON; nada foi gravado" % path)
    return data


def child(data, key, kind, path):
    """data[key] garantido do tipo `kind`; ausente ou null vira vazio.

    `setdefault` sozinho não basta: devolveria o null que já está lá.
    """
    value = data.get(key)
    if value is None:
        value = kind()
        data[key] = value
    elif not isinstance(value, kind):
        raise agent_error("%s: '%s' não é %s; nada foi gravado" % (path, key, kind.__name__))
    return value


def save(path, data):
    # Config que é symlink (para outro repo, outro gerenciador) é escrita no
    # alvo: um rename sobre o link o trocaria por arquivo comum, desligado dele.
    path = os.path.realpath(path)
    directory = os.path.dirname(path)
    os.makedirs(directory, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".agent_config.", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2, ensure_ascii=False)
            fh.write("\n")
        if os.path.exists(path):
            os.chmod(tmp, os.stat(path).st_mode & 0o777)
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


# --- MCP ----------------------------------------------------------------------


def repo_servers(mcp_dir):
    """{nome: spec} de <mcp-dir>/*.json, com ${HOME} trocado pelo $HOME.

    Só esse literal é substituído: um $(...) num headersHelper roda na hora da
    conexão e tem de chegar ao Claude Code intacto.
    Qualquer formatação vale (uma linha ou várias): quem lê é o parser.
    """
    servers = {}
    for path in sorted(glob.glob(os.path.join(mcp_dir, "*.json"))):
        name = os.path.splitext(os.path.basename(path))[0]
        try:
            with open(path, encoding="utf-8") as fh:
                raw = fh.read().replace("${HOME}", os.environ["HOME"])
            spec = json.loads(raw)
        except (OSError, ValueError) as exc:
            raise repo_error("%s inválido (%s)" % (path, exc))
        if not isinstance(spec, dict):
            raise repo_error("%s não é um objeto JSON" % path)
        servers[name] = spec
    return servers


def mcp_for(agent, spec):
    """O JSON do repo na forma que o agente guarda, ou None se não serve a ele."""
    if agent == "claude":
        return spec
    if CLAUDE_ONLY_KEYS & spec.keys():
        return None
    # O Cursor deduz o transporte de `command` (stdio) ou `url` (http); o `type`
    # é vocabulário do Claude Code e fica de fora.
    return {k: v for k, v in spec.items() if k != "type"}


def registered_servers(path):
    data = load_agent(path)
    servers = data.get("mcpServers")
    if servers is None:
        return {}
    if not isinstance(servers, dict):
        raise agent_error("%s: 'mcpServers' não é objeto" % path)
    return servers


def mcp_servers(mcp_dir):
    # Uma linha por servidor, JSON compacto: é o que o bash lê para o add-json.
    for name, spec in repo_servers(mcp_dir).items():
        print("%s\t%s" % (name, json.dumps(spec, ensure_ascii=False)))


def mcp_registered(path):
    for name in registered_servers(path):
        print(name)


def verdict(want, have):
    if want is None:
        return "skip"
    if have is None:
        return "add"
    # Compara os JSON já PARSEADOS: a ordem das chaves no arquivo do agente não
    # é a do repo, e comparar texto acusaria diferença em toda execução.
    return "ok" if have == want else "update"


def mcp_plan(agent, path, mcp_dir):
    wanted = repo_servers(mcp_dir)
    registered = registered_servers(path)
    for name, spec in wanted.items():
        print("%s\t%s" % (name, verdict(mcp_for(agent, spec), registered.get(name))))


def mcp_apply(agent, path, mcp_dir):
    if agent != "cursor":
        raise repo_error("mcp-apply só escreve no Cursor; o Claude Code registra via `claude mcp add-json`.")
    wanted = repo_servers(mcp_dir)
    data = load_agent(path)
    servers = child(data, "mcpServers", dict, path)
    lines, changed = [], False
    for name, spec in wanted.items():
        want = mcp_for(agent, spec)
        v = verdict(want, servers.get(name))
        lines.append("%s\t%s" % (name, v))
        if v in ("add", "update"):
            servers[name] = want
            changed = True
    # Grava antes de imprimir: quem lê "registrado" pode confiar que está no disco.
    if changed:
        save(path, data)
    print("\n".join(lines))


# --- Permissões ---------------------------------------------------------------


def shell_rule(agent, entry):
    """`entry` usa a gramática do Claude: "env" exato, "printenv:*" com args."""
    if agent == "claude":
        return "Bash(%s)" % entry
    # Cursor casa `Shell(base)` pela primeira palavra e `Shell(base:args)` com
    # glob nos argumentos. "gh auth token" vira "gh:auth token"; um `Shell(gh)`
    # bloquearia o gh inteiro, que é bem mais do que se quer negar.
    if ":" not in entry and " " in entry:
        base, _, args = entry.partition(" ")
        entry = "%s:%s" % (base, args)
    return "Shell(%s)" % entry


def read_rule(agent, path):
    if agent == "cursor":
        # Sem garantia de que o Cursor expande `~` no glob: vai o caminho absoluto.
        path = os.path.expanduser(path)
    return "Read(%s)" % path


def edit_rule(agent, path):
    if agent == "cursor":
        return "Write(%s)" % os.path.expanduser(path)
    # O Claude Code só consulta Edit(...) para o Edit e o Write: um Write(...)
    # seria aceito e nunca usado.
    return "Edit(%s)" % path


def deny_rules(agent, deny_path):
    # O deny do repo é a lista que protege os segredos: ausente ou quebrado é
    # erro, nunca "nada a negar" — senão o check diria "em dia" sobre o vazio.
    try:
        with open(deny_path, encoding="utf-8") as fh:
            spec = json.load(fh)
    except (OSError, ValueError) as exc:
        raise repo_error("%s inválido (%s)" % (deny_path, exc))
    if not isinstance(spec, dict) or not all(
        isinstance(spec.get(k, []), list) for k in ("read", "shell", "edit", "agent")
    ):
        raise repo_error('%s: esperado {"read": [...], "shell": [...], "edit": [...], "agent": [...]}' % deny_path)
    rules = [read_rule(agent, p) for p in spec.get("read", [])]
    rules += [shell_rule(agent, c) for c in spec.get("shell", [])]
    rules += [edit_rule(agent, p) for p in spec.get("edit", [])]
    # Bloquear subagente por nome é pedido do Claude Code (`Agent(<nome>)` em
    # permissions.deny); não verificamos equivalente no Cursor, então lá a
    # categoria é pulada de propósito.
    if agent == "claude":
        rules += ["Agent(%s)" % n for n in spec.get("agent", [])]
    if not rules:
        raise repo_error("%s não nega nada" % deny_path)
    return rules


def current_deny(data, path):
    perms = data.get("permissions")
    if perms is None:
        return []
    if not isinstance(perms, dict):
        raise agent_error("%s: 'permissions' não é objeto" % path)
    deny = perms.get("deny")
    if deny is None:
        return []
    if not isinstance(deny, list):
        raise agent_error("%s: 'permissions.deny' não é lista" % path)
    return deny


def deny_plan(agent, path, deny_path):
    rules = deny_rules(agent, deny_path)
    have = set(current_deny(load_agent(path), path))
    for rule in rules:
        if rule not in have:
            print(rule)


def deny_apply(agent, path, deny_path):
    rules = deny_rules(agent, deny_path)
    data = load_agent(path)
    have = set(current_deny(data, path))
    missing = [r for r in rules if r not in have]
    if not missing:
        return
    perms = child(data, "permissions", dict, path)
    if agent == "cursor":
        # cli-config.json exige as duas listas; o Cursor se auto-repara, mas não
        # custa entregar o arquivo já válido.
        child(perms, "allow", list, path)
    child(perms, "deny", list, path).extend(missing)
    save(path, data)
    for rule in missing:
        print(rule)


# --- Settings do Claude Code ---------------------------------------------------
# Chaves que só o Claude Code lê (skillOverrides, autoMode, …), declaradas num
# fragmento do settings.json (ADR 0028). Mesclar segue a regra do arquivo:
# objeto desce chave a chave, lista ganha o item que falta, escalar do repo
# vence — e o que a máquina tem a mais fica.


def repo_settings(agent, fragment_path):
    if agent != "claude":
        raise repo_error("settings/ declara chaves só do Claude Code; o Cursor não tem par.")
    try:
        with open(fragment_path, encoding="utf-8") as fh:
            spec = json.loads(fh.read().replace("${HOME}", os.environ["HOME"]))
    except (OSError, ValueError) as exc:
        raise repo_error("%s inválido (%s)" % (fragment_path, exc))
    if not isinstance(spec, dict) or not spec:
        raise repo_error("%s: esperado um objeto JSON não vazio" % fragment_path)
    return spec


def settings_diff(want, have, prefix=""):
    """[(chave, add|update)] onde a máquina ainda não contém o que o repo declara."""
    diffs = []
    for key, value in want.items():
        path = prefix + key
        if key not in have:
            diffs.append((path, "add"))
        elif isinstance(value, dict) and isinstance(have[key], dict):
            diffs += settings_diff(value, have[key], path + ".")
        elif isinstance(value, list) and isinstance(have[key], list):
            if any(item not in have[key] for item in value):
                diffs.append((path, "update"))
        elif have[key] != value:
            diffs.append((path, "update"))
    return diffs


def settings_merge(want, have):
    for key, value in want.items():
        if isinstance(value, dict) and isinstance(have.get(key), dict):
            settings_merge(value, have[key])
        elif isinstance(value, list) and isinstance(have.get(key), list):
            have[key].extend([item for item in value if item not in have[key]])
        else:
            have[key] = value


def settings_plan(agent, path, fragment_path):
    want = repo_settings(agent, fragment_path)
    for key, v in settings_diff(want, load_agent(path)):
        print("%s\t%s" % (key, v))


def settings_apply(agent, path, fragment_path):
    want = repo_settings(agent, fragment_path)
    data = load_agent(path)
    diffs = settings_diff(want, data)
    if not diffs:
        return
    settings_merge(want, data)
    save(path, data)
    for key, v in diffs:
        print("%s\t%s" % (key, v))


# --- Travas (hooks do Claude Code) ---------------------------------------------
# travas/travas.json declara os hooks no formato do settings.json, com
# ${TRAVAS_DIR} no lugar do caminho do pacote (ADR 0028). Hook é nosso quando o
# comando aponta para dentro de travas/: esses o repo atualiza e remove; os
# outros, da máquina, ficam onde estão.


def repo_travas(agent, travas_path):
    if agent != "claude":
        raise repo_error("travas/ declara hooks no formato do Claude Code; o Cursor não tem par.")
    travas_dir = os.path.dirname(os.path.realpath(travas_path))
    try:
        with open(travas_path, encoding="utf-8") as fh:
            spec = json.loads(fh.read().replace("${TRAVAS_DIR}", travas_dir))
    except (OSError, ValueError) as exc:
        raise repo_error("%s inválido (%s)" % (travas_path, exc))
    if not isinstance(spec, dict) or not spec or not all(isinstance(v, list) for v in spec.values()):
        raise repo_error('%s: esperado {"<Evento>": [grupos de hooks]}' % travas_path)
    return travas_dir, spec


def is_ours(hook, travas_dir):
    return isinstance(hook, dict) and (travas_dir + "/") in str(hook.get("command", ""))


def current_hooks(data, path):
    hooks = data.get("hooks")
    if hooks is None:
        return {}
    if not isinstance(hooks, dict):
        raise agent_error("%s: 'hooks' não é objeto" % path)
    return hooks


def ours_by_event(hooks, travas_dir):
    """{evento: [grupo só com os nossos hooks]}, na ordem em que estão."""
    found = {}
    for event, groups in hooks.items():
        for group in groups if isinstance(groups, list) else []:
            if not isinstance(group, dict) or not isinstance(group.get("hooks"), list):
                continue
            mine = [h for h in group["hooks"] if is_ours(h, travas_dir)]
            if mine:
                found.setdefault(event, []).append(dict(group, hooks=mine))
    return found


def hooks_diff(want, have):
    diffs = []
    for event in sorted(set(want) | set(have)):
        w, h = want.get(event), have.get(event)
        if w != h:
            diffs.append((event, "remove" if w is None else "add" if h is None else "update"))
    return diffs


def hooks_plan(agent, path, travas_path):
    travas_dir, want = repo_travas(agent, travas_path)
    have = ours_by_event(current_hooks(load_agent(path), path), travas_dir)
    for event, v in hooks_diff(want, have):
        print("%s\t%s" % (event, v))


def hooks_apply(agent, path, travas_path):
    travas_dir, want = repo_travas(agent, travas_path)
    data = load_agent(path)
    hooks = current_hooks(data, path)
    diffs = hooks_diff(want, ours_by_event(hooks, travas_dir))
    if not diffs:
        return
    # Os nossos saem de onde estiverem (grupo que fica vazio sai junto) e a
    # versão do repo entra no fim de cada evento.
    for event in list(hooks):
        if not isinstance(hooks[event], list):
            continue
        kept = []
        for group in hooks[event]:
            if isinstance(group, dict) and isinstance(group.get("hooks"), list):
                rest = [h for h in group["hooks"] if not is_ours(h, travas_dir)]
                if group["hooks"] and not rest:
                    continue
                group = dict(group, hooks=rest)
            kept.append(group)
        if kept:
            hooks[event] = kept
        else:
            del hooks[event]
    for event, groups in want.items():
        hooks.setdefault(event, []).extend(groups)
    data["hooks"] = hooks
    save(path, data)
    for event, v in diffs:
        print("%s\t%s" % (event, v))


# --- OpenCode ------------------------------------------------------------------
# Terceiro alvo do pacote, só onde há OpenCode 2.x (ADR 0046; a detecção é do
# lib.sh). Nada do que o Claude Code ou o Cursor leem muda por causa dele: o alvo
# mescla chaves do opencode.json e GERA arquivos no diretório de config.
#
# O deny.json vira `policies`, e não `permissions`: no OpenCode vale a última regra
# de permissão que casa, e a do subagente entra depois da global, então um
# subagente com leitura liberada reabriria o que o deny fecha. A policy vence
# qualquer regra, e não expande "~". Entrada de caminho vira "*" + o caminho sem o
# "~/", com "**" virando "*" ("*" atravessa "/"): casa o absoluto e o relativo a
# partir de "~". Furo aceito: o recurso de um arquivo DENTRO do diretório da
# sessão é relativo a ele, então uma sessão aberta dentro da própria pasta negada
# (ex. ~/ObsidianVault/daily) vê só "2026-01-01.md" e o padrão não casa. Entrada
# de shell segue a semântica do deny.json: "a:*" é prefixo, o resto é exato.

OPENCODE_FRAGMENT_KEYS = {"share", "permissions", "policies"}
OPENCODE_CLI_KEYS = {"plugins", "keybinds"}
OPENCODE_CLI_SCHEMA = "https://opencode.ai/v2/cli.json"
OPENCODE_MARK_PREFIX = "<!-- gerado por agents/hooks/agent_config.py a partir de "
OPENCODE_MARK_SUFFIX = "; não edite -->"
OPENCODE_MARK_RE = re.compile(r"^<!-- gerado por agents/hooks/agent_config\.py a partir de .+; não edite -->$", re.M)

# Ferramenta do Claude Code -> ação de permissão do OpenCode.
CLAUDE_TOOL_ACTIONS = {
    "Read": "read",
    "Grep": "grep",
    "Glob": "glob",
    "Bash": "shell",
    "Edit": "edit",
    "Write": "edit",
    "NotebookEdit": "edit",
    "WebFetch": "webfetch",
    "WebSearch": "websearch",
    "Agent": "subagent",
    "Skill": "skill",
    "TodoWrite": "todowrite",
}

# O OpenCode só aceita #RRGGBB; as cores nomeadas do Claude Code vêm daqui.
CLAUDE_COLORS = {
    "red": "#EF4444",
    "blue": "#3B82F6",
    "green": "#22C55E",
    "yellow": "#EAB308",
    "purple": "#A855F7",
    "orange": "#F97316",
    "pink": "#EC4899",
    "cyan": "#06B6D4",
}

MODEL_ALIASES = ("opus", "sonnet", "haiku")
MODEL_REF = re.compile(r"^[^/#\s]+/[^#\s]+$")
DENY_ALL = {"action": "*", "resource": "*", "effect": "deny"}


def parse_scalar(raw, path, key):
    raw = raw.strip()
    if raw.startswith('"'):
        try:
            return json.loads(raw)
        except ValueError as exc:
            raise repo_error("%s: '%s' entre aspas inválido (%s)" % (path, key, exc))
    if raw.startswith("'") and raw.endswith("'") and len(raw) > 1:
        return raw[1:-1].replace("''", "'")
    return re.split(r"\s#", raw, maxsplit=1)[0].strip()


def read_markdown(path):
    """(frontmatter, corpo) de um .md do repo. Frontmatter: só chaves de topo.

    Valor escalar vira str; lista em bloco (`- item`) vira list; bloco `>`/`|` e
    mapa aninhado ficam como None (quem precisa da chave reclama). Não é um
    parser de YAML: é o que os subagentes e as skills do pacote usam.
    """
    try:
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
    except OSError as exc:
        raise repo_error("%s ilegível (%s)" % (path, exc))
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        raise repo_error("%s: sem frontmatter" % path)
    try:
        end = next(i for i in range(1, len(lines)) if lines[i].strip() == "---")
    except StopIteration:
        raise repo_error("%s: frontmatter sem o --- final" % path)
    data, key = {}, None
    for line in lines[1:end]:
        top = re.match(r"^([A-Za-z][A-Za-z0-9_-]*):[ \t]*(.*)$", line)
        if top:
            key, value = top.group(1), top.group(2).strip()
            data[key] = parse_scalar(value, path, key) if value and value not in (">", "|", ">-", "|-") else None
        elif key is not None and re.match(r"^\s*-\s+\S", line) and data[key] in (None, []):
            item = parse_scalar(re.sub(r"^\s*-\s+", "", line), path, key)
            data[key] = (data[key] or []) + [item]
    return data, "\n".join(lines[end + 1 :]).strip("\n")


def required_text(data, key, path):
    value = data.get(key)
    if not isinstance(value, str) or not value:
        raise repo_error("%s: '%s' ausente ou fora do formato de uma linha" % (path, key))
    return value


def tool_names(data, key, path):
    """Lista de nomes de `tools`/`disallowedTools` (vírgulas ou lista em bloco), ou None."""
    if key not in data:
        return None
    value = data[key]
    if isinstance(value, str):
        names = [n.strip() for n in value.split(",")]
    elif isinstance(value, list):
        names = [n.strip() for n in value]
    else:
        raise repo_error("%s: '%s' fora do formato (vírgulas ou lista)" % (path, key))
    if not names or not all(names):
        raise repo_error("%s: '%s' vazio ou com item vazio" % (path, key))
    return names


def tool_actions(names, key, path):
    actions = []
    for name in names:
        action = CLAUDE_TOOL_ACTIONS.get(name)
        if action is None:
            raise repo_error(
                "%s: '%s' lista %r, sem tradução para o OpenCode; acrescente-o em CLAUDE_TOOL_ACTIONS de agent_config.py"
                % (path, key, name)
            )
        if action not in actions:
            actions.append(action)
    return actions


def rule(action, resource, effect):
    return {"action": action, "resource": resource, "effect": effect}


def subagent_permissions(tools, disallowed, default):
    """Os `permissions` do agente: `tools` vira "nega tudo, devolve o que a lista nomeia".

    A devolução reaproveita as regras do ruleset padrão daquela ação, na ordem,
    para que o auditor com Bash continue perguntando em shell como a sessão. Ação
    sem regra no padrão: ferramenta liberada, `external_directory` perguntando.
    """
    rules = []
    if tools is not None:
        rules.append(dict(DENY_ALL))
        for action in tools + ["external_directory"]:
            own = [dict(r) for r in default if r["action"] == action]
            rules += own or [rule(action, "*", "ask" if action == "external_directory" else "allow")]
    rules += [rule(action, "*", "deny") for action in disallowed or []]
    return rules


def repo_opencode(fragment_path):
    """O fragmento do opencode.json do repo: {share, permissions, policies}."""
    try:
        with open(fragment_path, encoding="utf-8") as fh:
            spec = json.loads(fh.read().replace("${HOME}", os.environ["HOME"]))
    except (OSError, ValueError) as exc:
        raise repo_error("%s inválido (%s)" % (fragment_path, exc))
    if not isinstance(spec, dict) or not spec or set(spec) - OPENCODE_FRAGMENT_KEYS:
        raise repo_error("%s: esperado um objeto só com %s" % (fragment_path, sorted(OPENCODE_FRAGMENT_KEYS)))
    if not isinstance(spec.get("share", ""), str):
        raise repo_error("%s: 'share' não é texto" % fragment_path)
    for key in ("permissions", "policies"):
        items = spec.get(key, [])
        if not isinstance(items, list) or not all(isinstance(i, dict) for i in items):
            raise repo_error("%s: '%s' não é lista de regras" % (fragment_path, key))
    spec["permissions"] = [normal_rule(r, fragment_path) for r in spec.get("permissions", [])]
    spec["policies"] = [normal_rule(r, fragment_path) for r in spec.get("policies", [])]
    return spec


def normal_rule(item, path):
    if set(item) != {"action", "resource", "effect"} or not all(isinstance(v, str) for v in item.values()):
        raise repo_error('%s: regra fora de {"action","resource","effect"}: %r' % (path, item))
    return rule(item["action"], item["resource"], item["effect"])


def path_patterns(entry):
    """Padrões do OpenCode para uma entrada de caminho do deny.json."""
    base = entry[2:] if entry.startswith("~/") else entry
    # `a/**/b` casa `a/b` no deny.json; com "**" virando "*" sobraria um "/" a
    # mais, então a forma sem o trecho também entra.
    forms = [base] + ([base.replace("/**/", "/")] if "/**/" in base else [])
    return [re.sub(r"\*+", "*", "*" + f.replace("**", "*")) for f in forms]


def deny_policies(deny_path):
    """As `policies` do deny.json (tool.use, deny), na ordem do arquivo."""
    try:
        with open(deny_path, encoding="utf-8") as fh:
            spec = json.load(fh)
    except (OSError, ValueError) as exc:
        raise repo_error("%s inválido (%s)" % (deny_path, exc))
    if not isinstance(spec, dict) or not all(
        isinstance(spec.get(k, []), list) for k in ("read", "shell", "edit", "agent")
    ):
        raise repo_error('%s: esperado {"read": [...], "shell": [...], "edit": [...], "agent": [...]}' % deny_path)
    # A categoria "agent" fica de fora de propósito: bloquear subagente por nome é
    # pedido do Claude Code; não verificamos equivalente no OpenCode.
    resources = []
    for entry in spec.get("read", []):
        resources += ["read:" + p for p in path_patterns(entry)]
    for entry in spec.get("shell", []):
        # "a:*" é prefixo no deny.json; " *" no fim casa com e sem argumento.
        resources.append("shell:" + entry.replace(":", " ", 1))
    for entry in spec.get("edit", []):
        resources += ["edit:" + p for p in path_patterns(entry)]
    if not resources:
        raise repo_error("%s não nega nada" % deny_path)
    return [{"action": "tool.use", "resource": r, "effect": "deny"} for r in resources]


def repo_block(pkg_dir, machine):
    """O que o repo declara para o opencode.json: {share, instructions, permissions, policies}."""
    fragment = repo_opencode(os.path.join(pkg_dir, "opencode", "config.json"))
    user = os.path.join(pkg_dir, "instructions", "user.md")
    if not os.path.isfile(user):
        raise repo_error("%s não existe" % user)
    instructions = [user]
    host = os.path.join(pkg_dir, "instructions", "machines", machine + ".md")
    if os.path.isfile(host):
        instructions.append(host)
    policies = deny_policies(os.path.join(pkg_dir, "permissions", "deny.json")) + fragment["policies"]
    want = {"instructions": instructions, "permissions": fragment["permissions"], "policies": policies}
    if "share" in fragment:
        want["share"] = fragment["share"]
    return want


def block_state(block, have):
    """ok | add | update para uma lista em que a ordem importa (vale a última que casa)."""
    if not block or have[len(have) - len(block) :] == block:
        return "ok"
    return "update" if any(item in block for item in have) else "add"


def block_merge(block, have):
    """Os itens do repo saem de onde estão e o bloco entra, contíguo, no fim."""
    return [item for item in have if item not in block] + block


def opencode_json_diffs(want, data, path):
    diffs = []
    if "share" in want and data.get("share") != want["share"]:
        diffs.append(("share", "add" if "share" not in data else "update"))
    have = child(data, "instructions", list, path) if "instructions" in data else []
    missing = [p for p in want["instructions"] if p not in have]
    if missing:
        diffs.append(("instructions", "update" if have else "add"))
    for key in ("permissions", "policies"):
        have = child(data, key, list, path) if key in data else []
        state = block_state(want[key], have)
        if state != "ok":
            diffs.append((key, state))
    return diffs


def opencode_json_merge(want, data, path):
    if "share" in want:
        data["share"] = want["share"]
    have = child(data, "instructions", list, path)
    have.extend(p for p in want["instructions"] if p not in have)
    for key in ("permissions", "policies"):
        data[key] = block_merge(want[key], child(data, key, list, path))


# cli.json do TUI (OpenCode 2.x): o próprio OpenCode o reescreve (`plugin add`
# regrava o arquivo, o atalho de verbosidade grava session.verbosity, trocar de tema
# grava theme), então o repo só declara `plugins` e `keybinds`, e o resto é dele.
# Fragmento ausente = nada a fazer no cli.json.


def repo_cli(pkg_dir):
    """O fragmento opencode/cli.json do repo ({plugins, keybinds}), ou None se não existe."""
    path = os.path.join(pkg_dir, "opencode", "cli.json")
    if not os.path.lexists(path):
        return None
    try:
        with open(path, encoding="utf-8") as fh:
            spec = json.load(fh)
    except (OSError, ValueError) as exc:
        raise repo_error("%s inválido (%s)" % (path, exc))
    if not isinstance(spec, dict) or not spec or set(spec) - OPENCODE_CLI_KEYS:
        raise repo_error("%s: esperado um objeto só com %s" % (path, sorted(OPENCODE_CLI_KEYS)))
    plugins = spec.get("plugins", [])
    if not isinstance(plugins, list) or not all(plugin_name(p) for p in plugins):
        raise repo_error('%s: "plugins" não é lista de "pacote@versao" ou {"package": ...}' % path)
    for plugin in plugins:
        if isinstance(plugin, dict) and not isinstance(plugin.get("options", {}), dict):
            raise repo_error("%s: 'options' de %r não é objeto" % (path, plugin["package"]))
    keybinds = spec.get("keybinds", {})
    if not isinstance(keybinds, dict) or not all(isinstance(v, str) for v in keybinds.values()):
        raise repo_error('%s: "keybinds" não é objeto de id -> atalho (texto)' % path)
    return spec


def plugin_name(item):
    """O nome do pacote sem a versão, ou None se o item não é string nem {"package": texto}.

    O `@` do escopo (`@escopo/nome`) não separa versão: só um `@` depois do primeiro
    caractere separa.
    """
    if isinstance(item, dict):
        item = item.get("package")
    if not isinstance(item, str) or not item:
        return None
    at = item.rfind("@")
    return item[:at] if at > 0 else item


def plugin_slot(have, item):
    """Posição, em `have`, do plugin que é o mesmo pacote de `item`; None se não há."""
    name = plugin_name(item)
    return next((i for i, other in enumerate(have) if plugin_name(other) == name), None)


def opencode_cli_diffs(want, data, path):
    """[(cli.json:<chave>, add|update)]. `add` quando nada do que o repo declara está lá."""
    diffs = []
    if "keybinds" in want:
        have = child(data, "keybinds", dict, path)
        if any(have.get(k) != v for k, v in want["keybinds"].items()):
            diffs.append(("cli.json:keybinds", "update" if any(k in have for k in want["keybinds"]) else "add"))
    if "plugins" in want:
        have = child(data, "plugins", list, path)
        slots = [plugin_slot(have, item) for item in want["plugins"]]
        if any(i is None or have[i] != item for i, item in zip(slots, want["plugins"])):
            diffs.append(("cli.json:plugins", "update" if any(i is not None for i in slots) else "add"))
    return diffs


def opencode_cli_merge(want, data, path):
    if "keybinds" in want:
        child(data, "keybinds", dict, path).update(want["keybinds"])
    if "plugins" in want:
        have = child(data, "plugins", list, path)
        for item in want["plugins"]:
            slot = plugin_slot(have, item)
            if slot is None:
                have.append(copy.deepcopy(item))
            else:
                have[slot] = copy.deepcopy(item)


def opencode_cli_state(config_dir, pkg_dir):
    """(fragmento, caminho, dados, diffs) do cli.json, ou None sem fragmento no repo."""
    want = repo_cli(pkg_dir)
    if want is None:
        return None
    path = os.path.join(config_dir, "cli.json")
    data = load_agent(path)
    if not os.path.lexists(path):
        data = {"$schema": OPENCODE_CLI_SCHEMA}
    return want, path, data, opencode_cli_diffs(want, data, path)


def load_models(config_dir):
    """O mapa opus/sonnet/haiku -> provedor/modelo da máquina; ausente = {}."""
    path = os.path.join(config_dir, "modelos.json")
    data = load_agent(path)
    for alias in MODEL_ALIASES:
        if alias in data and not (isinstance(data[alias], str) and MODEL_REF.match(data[alias])):
            raise agent_error("%s: '%s' não é provedor/modelo; nada foi gravado" % (path, alias))
    return data


def mark(source):
    return OPENCODE_MARK_PREFIX + source + OPENCODE_MARK_SUFFIX


def render(front, source, body):
    """O arquivo gerado: frontmatter (linhas já prontas), o marcador e o corpo."""
    parts = ["---"] + front + ["---", mark(source)]
    return "\n".join(parts) + "\n" + ("\n" + body + "\n" if body else "")


def jline(value):
    return json.dumps(value, ensure_ascii=False)


def generated_agents(pkg_dir, config_dir, default, models):
    """{caminho: conteúdo} do agents/<id>.md de cada subagents/<nome>.md."""
    files = {}
    for src in sorted(glob.glob(os.path.join(pkg_dir, "subagents", "*.md"))):
        data, body = read_markdown(src)
        rel = os.path.relpath(src, os.path.dirname(pkg_dir))
        agent_id = os.path.splitext(os.path.basename(src))[0].lower()
        target = os.path.join(config_dir, "agents", agent_id + ".md")
        if target in files:
            raise repo_error("%s: o id '%s' já vem de outro subagente" % (src, agent_id))
        tools = tool_names(data, "tools", src)
        disallowed = tool_names(data, "disallowedTools", src)
        front = ["description: " + jline(required_text(data, "description", src)), "mode: subagent"]
        model = data.get("model")
        if model is not None and not isinstance(model, str):
            raise repo_error("%s: 'model' fora do formato de uma linha" % src)
        if model and model != "inherit":
            if model not in MODEL_ALIASES:
                raise repo_error("%s: model %r sem tradução (inherit, %s)" % (src, model, ", ".join(MODEL_ALIASES)))
            if model in models:
                front.append("model: " + jline(models[model]))
        color = data.get("color")
        if color:
            if color not in CLAUDE_COLORS:
                raise repo_error("%s: color %r fora do mapa (%s)" % (src, color, ", ".join(CLAUDE_COLORS)))
            front.append("color: " + jline(CLAUDE_COLORS[color]))
        perms = subagent_permissions(
            tool_actions(tools, "tools", src) if tools else None,
            tool_actions(disallowed, "disallowedTools", src) if disallowed else None,
            default,
        )
        if perms:
            front.append("permissions:")
            front += ["  - " + json.dumps(r, ensure_ascii=False) for r in perms]
        files[target] = render(front, rel, body)
    return files


def command_skills(pkg_dir):
    """Skills do pacote que ganham comando: fork, só-manual ou com $ARGUMENTS; fora, as com ${CLAUDE_SESSION_ID}."""
    found = []
    for skill_dir in sorted(glob.glob(os.path.join(pkg_dir, "skills", "*"))):
        skill_md = os.path.join(skill_dir, "SKILL.md")
        if not os.path.isfile(skill_md):
            continue
        data, _ = read_markdown(skill_md)
        with open(skill_md, encoding="utf-8") as fh:
            text = fh.read()
        wanted = data.get("context") == "fork" or data.get("disable-model-invocation") == "true" or "$ARGUMENTS" in text
        if not wanted or skill_uses_session_id(skill_dir):
            continue
        found.append((os.path.basename(skill_dir), skill_md, data))
    return found


def skill_uses_session_id(skill_dir):
    for root, _, names in os.walk(skill_dir):
        for name in names:
            try:
                with open(os.path.join(root, name), "rb") as fh:
                    if b"CLAUDE_SESSION_ID" in fh.read():
                        return True
            except OSError:
                continue
    return False


def generated_commands(pkg_dir, config_dir):
    """{caminho: conteúdo} do commands/<skill>.md de cada skill que o pede."""
    hand = {os.path.basename(p) for p in glob.glob(os.path.join(pkg_dir, "opencode", "commands", "*.md"))}
    files = {}
    for name, skill_md, data in command_skills(pkg_dir):
        if name + ".md" in hand:
            raise repo_error("%s: já existe opencode/commands/%s.md à mão" % (skill_md, name))
        front = ["description: " + jline(required_text(data, "description", skill_md))]
        if data.get("context") == "fork":
            front.append("subagent: true")
        body = (
            "Carregue a skill `%s` com a ferramenta skill e siga as instruções dela do começo ao fim.\n\n"
            "Pedido do dono (vazio quando ele não disse nada): $ARGUMENTS" % name
        )
        files[os.path.join(config_dir, "commands", name + ".md")] = render(
            front, os.path.relpath(skill_md, os.path.dirname(pkg_dir)), body
        )
    return files


def read_text(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read()
    except (OSError, ValueError) as exc:
        raise agent_error("%s ilegível (%s); nada foi gravado" % (path, exc))


def is_generated(path):
    return os.path.isfile(path) and not os.path.islink(path) and bool(OPENCODE_MARK_RE.search(read_text(path)))


def generated_diffs(config_dir, wanted):
    """[(caminho, add|update|remove|skip)]. Só arquivo com o marcador é do setup."""
    diffs = []
    for path, content in wanted.items():
        if not os.path.lexists(path):
            diffs.append((path, "add"))
        elif not is_generated(path):
            diffs.append((path, "skip"))
        elif read_text(path) != content:
            diffs.append((path, "update"))
    for kind in ("agents", "commands"):
        for path in sorted(glob.glob(os.path.join(config_dir, kind, "*.md"))):
            if path not in wanted and is_generated(path):
                diffs.append((path, "remove"))
    return diffs


def write_generated(path, content):
    directory = os.path.dirname(path)
    os.makedirs(directory, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".agent_config.", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(content)
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


def opencode_state(config_dir, pkg_dir, machine):
    """Tudo o que plan e apply precisam, lido e validado antes de qualquer escrita."""
    want = repo_block(pkg_dir, machine)
    json_path = os.path.join(config_dir, "opencode.json")
    blocked = os.path.lexists(os.path.join(config_dir, "opencode.jsonc")) and not os.path.lexists(json_path)
    data = load_agent(json_path)
    diffs = [] if blocked else opencode_json_diffs(want, data, json_path)
    wanted = generated_agents(pkg_dir, config_dir, want["permissions"], load_models(config_dir))
    wanted.update(generated_commands(pkg_dir, config_dir))
    files = generated_diffs(config_dir, wanted)
    cli = opencode_cli_state(config_dir, pkg_dir)
    return want, json_path, data, blocked, diffs, wanted, files, cli


def opencode_lines(config_dir, blocked, diffs, files, cli):
    lines = [("opencode.jsonc", "blocked")] if blocked else list(diffs)
    lines += cli[3] if cli else []
    return lines + [(os.path.relpath(p, config_dir), v) for p, v in files]


def opencode_plan(config_dir, pkg_dir, machine):
    _, _, _, blocked, diffs, _, files, cli = opencode_state(config_dir, pkg_dir, machine)
    for key, v in opencode_lines(config_dir, blocked, diffs, files, cli):
        print("%s\t%s" % (key, v))


def opencode_apply(config_dir, pkg_dir, machine):
    want, json_path, data, blocked, diffs, wanted, files, cli = opencode_state(config_dir, pkg_dir, machine)
    if diffs:
        opencode_json_merge(want, data, json_path)
        save(json_path, data)
    if cli and cli[3]:
        cli_want, cli_path, cli_data, _ = cli
        opencode_cli_merge(cli_want, cli_data, cli_path)
        save(cli_path, cli_data)
    for path, verdict in files:
        if verdict == "remove":
            os.unlink(path)
        elif verdict in ("add", "update"):
            write_generated(path, wanted[path])
    for key, v in opencode_lines(config_dir, blocked, diffs, files, cli):
        print("%s\t%s" % (key, v))


def main(argv):
    cmd, args = (argv[0], argv[1:]) if argv else ("", [])
    if cmd == "mcp-servers" and len(args) == 1:
        return mcp_servers(*args)
    if cmd == "mcp-registered" and len(args) == 1:
        return mcp_registered(*args)
    if len(args) == 3 and cmd in ("opencode-plan", "opencode-apply"):
        return {"opencode-plan": opencode_plan, "opencode-apply": opencode_apply}[cmd](*args)
    if len(args) == 3 and args[0] in ("claude", "cursor"):
        handler = {
            "mcp-plan": mcp_plan,
            "mcp-apply": mcp_apply,
            "deny-plan": deny_plan,
            "deny-apply": deny_apply,
            "settings-plan": settings_plan,
            "settings-apply": settings_apply,
            "hooks-plan": hooks_plan,
            "hooks-apply": hooks_apply,
        }.get(cmd)
        if handler:
            return handler(*args)
    sys.exit(__doc__)


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except ConfigError as exc:
        print(exc, file=sys.stderr)
        sys.exit(exc.code)
