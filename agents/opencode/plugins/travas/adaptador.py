#!/usr/bin/env python3
"""Adaptador das travas para o OpenCode: traduz o evento dele para o JSON de hook do Claude Code.

O plugin `server.ts` (só cola) manda um pedido em JSON no stdin e lê a resposta no stdout:

  {"evento": "antes",  "sessao": <id>, "cwd": <pasta>, "ferramenta": "shell|edit|write|patch|...",
   "entrada": {...}, "chamada": <id da chamada>}
  {"evento": "depois", ..., "status": "completed|error", "aplicados": [{"target": <caminho>}, ...]}
  {"evento": "parar",  "sessao": <id>, "cwd": <pasta>, "parada_ativa": <bool>}

  → {"nega": "<motivo>"}    (antes: a trava recusou a ferramenta)
  → {"pergunta": "<motivo>"} (antes: a trava pede a aprovação do dono, `permissionDecision: "ask"`)
  → {"bloqueia": "<motivo>"} (parar: a trava pede mais um turno)
  → {}                       (nada a dizer)

O que cada evento dispara sai de `agents/travas/travas.json`, o mesmo arquivo que o setup registra
no Claude Code: `PreToolUse` no antes, `PostToolUse` (ou `PostToolUseFailure`, quando a ferramenta
falhou) no depois e `Stop` no parar. O hook recebe o JSON que o Claude Code lhe daria
(`session_id`, `tool_name`, `tool_input`, `cwd`, `tool_use_id`, `stop_hook_active`); nenhuma trava
lê o resto. Nome de ferramenta: shell vira Bash, edit vira Edit, write vira Write; um patch do
OpenCode vira um Edit por arquivo. Ferramenta sem trava (read, grep…) não dispara nada.
Se uma trava nega e outra pergunta, vale a recusa. O que o plugin faz com a pergunta está no
cabeçalho do `server.ts`.

Falha do adaptador ou de uma trava (timeout, saída que não é JSON, comando que sumiu) nunca vira
recusa nem bloqueio: o hook que falha derruba a execução do OpenCode, e a trava de que ninguém
sente falta é a que não segurou (ADR 0027).
"""

import json
import os
import re
import subprocess
import sys

TRAVAS_DIR = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "travas"))

# Ferramenta do OpenCode → nome que as travas conhecem.
TOOL_NAMES = {"shell": "Bash", "edit": "Edit", "write": "Write"}
# Cabeçalhos do patch do OpenCode que nomeiam um arquivo.
PATCH_HEADER = re.compile(r"^\*\*\* (?:Add File|Update File|Delete File|Move to):\s*(.+?)\s*$", re.M)
DEFAULT_TIMEOUT = 30
EVENTS = {"antes": "PreToolUse", "parar": "Stop"}


def load_spec(travas_dir=TRAVAS_DIR):
    """O `travas.json`, com ${TRAVAS_DIR} no caminho da pasta; {} quando falta ou não é JSON."""
    try:
        with open(os.path.join(travas_dir, "travas.json"), encoding="utf-8") as fh:
            spec = json.loads(fh.read().replace("${TRAVAS_DIR}", travas_dir))
    except (OSError, ValueError):
        return {}
    return spec if isinstance(spec, dict) else {}


def absolute(path, cwd):
    return os.path.normpath(os.path.join(cwd, os.path.expanduser(path)))


def claude_calls(request):
    """Os pares (tool_name, tool_input, cwd) com que o Claude Code chamaria as travas por este pedido.

    Lista vazia: a ferramenta não tem trava. `cwd` do Bash é o `workdir` da chamada, que é de onde
    o comando roda; o das ferramentas de arquivo é o da sessão.
    """
    tool, data, cwd = request.get("ferramenta"), request.get("entrada"), request.get("cwd") or os.getcwd()
    if not isinstance(data, dict):
        return []
    if tool == "shell":
        command = data.get("command")
        if not isinstance(command, str):
            return []
        workdir = data.get("workdir")
        where = absolute(workdir, cwd) if isinstance(workdir, str) and workdir else cwd
        tool_input = {"command": command}
        if data.get("background") is True:
            tool_input["run_in_background"] = True
        return [("Bash", tool_input, where)]
    if tool in ("edit", "write"):
        path = data.get("path")
        return [(TOOL_NAMES[tool], {"file_path": absolute(path, cwd)}, cwd)] if isinstance(path, str) and path else []
    if tool == "patch":
        # Depois da ferramenta, os caminhos que ela aplicou; antes, os cabeçalhos do texto do patch.
        applied = request.get("aplicados")
        if request.get("evento") == "depois" and isinstance(applied, list):
            paths = [a.get("target") or a.get("resource") for a in applied if isinstance(a, dict)]
        else:
            text = data.get("patchText")
            paths = PATCH_HEADER.findall(text) if isinstance(text, str) else []
        return [("Edit", {"file_path": absolute(p, cwd)}, cwd) for p in dict.fromkeys(paths) if isinstance(p, str) and p]
    return []


def hook_event(request):
    """O nome do evento do Claude Code, ou None."""
    if request.get("evento") == "depois":
        return "PostToolUse" if request.get("status") == "completed" else "PostToolUseFailure"
    return EVENTS.get(request.get("evento"))


def hooks_for(spec, event, tool_name, travas_dir):
    """(comando, timeout) de cada hook de `event` cujo matcher casa com `tool_name`, na ordem do arquivo."""
    found = []
    for group in spec.get(event) or []:
        if not isinstance(group, dict):
            continue
        matcher = group.get("matcher") or ""
        if matcher not in ("", "*") and not re.fullmatch(matcher, tool_name or ""):
            continue
        for hook in group.get("hooks") or []:
            if isinstance(hook, dict) and hook.get("type") == "command" and hook.get("command"):
                found.append((hook["command"], hook.get("timeout") or DEFAULT_TIMEOUT))
    return found


def run_hook(command, payload, env):
    """A saída JSON do hook; None se ele falhou, estourou o tempo ou não disse JSON."""
    cwd = payload.get("cwd")
    try:
        done = subprocess.run(
            command[0], shell=True, input=json.dumps(payload), capture_output=True, text=True,
            timeout=command[1], env=env, cwd=cwd if cwd and os.path.isdir(cwd) else None,
        )
        out = json.loads(done.stdout) if done.returncode == 0 and done.stdout.strip() else None
    except (OSError, ValueError, subprocess.SubprocessError):
        return None
    return out if isinstance(out, dict) else None


def handle(request, spec=None, travas_dir=TRAVAS_DIR):
    """O pedido do plugin → a resposta; despacha para as travas do `travas.json`."""
    spec = load_spec(travas_dir) if spec is None else spec
    event = hook_event(request)
    session = request.get("sessao")
    if not event or not isinstance(session, str) or not session:
        return {}
    env = dict(os.environ)
    if request.get("evento") == "parar":
        calls = [(None, {}, request.get("cwd") or os.getcwd())]
    else:
        calls = claude_calls(request)

    reasons, questions = [], []
    for tool_name, tool_input, cwd in calls:
        payload = {"session_id": session, "hook_event_name": event, "cwd": cwd}
        if tool_name:
            payload.update(tool_name=tool_name, tool_input=tool_input, tool_use_id=str(request.get("chamada") or ""))
        else:
            payload["stop_hook_active"] = bool(request.get("parada_ativa"))
        for command in hooks_for(spec, event, tool_name, travas_dir):
            out = run_hook(command, payload, env)
            if not out:
                continue
            if event == "PreToolUse":
                decision = out.get("hookSpecificOutput") or {}
                if decision.get("permissionDecision") == "deny":
                    return {"nega": str(decision.get("permissionDecisionReason") or "recusado por uma trava")}
                if decision.get("permissionDecision") == "ask":
                    questions.append(str(decision.get("permissionDecisionReason") or "uma trava pede a aprovação do dono"))
            elif event == "Stop" and out.get("decision") == "block":
                reasons.append(str(out.get("reason") or "uma trava pede mais um passo antes de encerrar"))
    if questions:
        return {"pergunta": "\n\n".join(dict.fromkeys(questions))}
    return {"bloqueia": "\n\n".join(reasons)} if reasons else {}


def main():
    try:
        request = json.load(sys.stdin)
        response = handle(request) if isinstance(request, dict) else {}
    except Exception:  # o adaptador nunca derruba o OpenCode: sem resposta, nenhuma trava age
        response = {}
    json.dump(response, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
