#!/usr/bin/env python3
"""Compara e mescla a config dos agentes (Claude Code, Cursor) com o repo.

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

Saída 2 = arquivo do REPO inválido (mcp/*.json, deny.json, settings/*.json);
saída 3 = arquivo do AGENTE ilegível. A mensagem vai para stderr.

Uso:
  agent_config.py mcp-servers <mcp-dir>                    (nome\\tjson-compacto)
  agent_config.py mcp-registered <arquivo>                 (um nome por linha)
  agent_config.py mcp-plan  <claude|cursor> <arquivo> <mcp-dir>
  agent_config.py mcp-apply cursor <arquivo> <mcp-dir>
  agent_config.py deny-plan  <claude|cursor> <arquivo> <deny.json>
  agent_config.py deny-apply <claude|cursor> <arquivo> <deny.json>
  agent_config.py settings-plan  claude <arquivo> <fragmento.json>  (chave\\tadd|update)
  agent_config.py settings-apply claude <arquivo> <fragmento.json>
"""

import glob
import json
import os
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


def deny_rules(agent, deny_path):
    # O deny do repo é a lista que protege os segredos: ausente ou quebrado é
    # erro, nunca "nada a negar" — senão o check diria "em dia" sobre o vazio.
    try:
        with open(deny_path, encoding="utf-8") as fh:
            spec = json.load(fh)
    except (OSError, ValueError) as exc:
        raise repo_error("%s inválido (%s)" % (deny_path, exc))
    if not isinstance(spec, dict) or not all(
        isinstance(spec.get(k, []), list) for k in ("read", "shell")
    ):
        raise repo_error('%s: esperado {"read": [...], "shell": [...]}' % deny_path)
    rules = [read_rule(agent, p) for p in spec.get("read", [])]
    rules += [shell_rule(agent, c) for c in spec.get("shell", [])]
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


def main(argv):
    cmd, args = (argv[0], argv[1:]) if argv else ("", [])
    if cmd == "mcp-servers" and len(args) == 1:
        return mcp_servers(*args)
    if cmd == "mcp-registered" and len(args) == 1:
        return mcp_registered(*args)
    if len(args) == 3 and args[0] in ("claude", "cursor"):
        handler = {
            "mcp-plan": mcp_plan,
            "mcp-apply": mcp_apply,
            "deny-plan": deny_plan,
            "deny-apply": deny_apply,
            "settings-plan": settings_plan,
            "settings-apply": settings_apply,
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
