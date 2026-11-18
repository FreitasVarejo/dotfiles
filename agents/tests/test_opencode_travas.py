"""O plugin `travas` do OpenCode (agents/opencode/plugins/travas/): o `adaptador.py` que traduz o evento
dele para o JSON de hook do Claude Code e despacha pelo `travas.json`, e o `server.ts` que o chama.

O adaptador se testa em Python, contra um `travas.json` falso e contra as travas de verdade; o `server.ts`
roda no Node com um `ctx` falso (o OpenCode só carrega o plugin na partida dele) e chama o adaptador real.
Cada teste monta vault, runtime, repo e PATH temporários, com um `freitask` falso: nada do $HOME real
entra na conta."""

import importlib.machinery
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
PKG = Path(__file__).resolve().parents[1]
PLUGIN = PKG / "opencode" / "plugins" / "travas"
TRAVAS = PKG / "travas"
PENDENCIAS = PKG / "skills" / "fechar" / "scripts" / "pendencias"
NODE = shutil.which("node")
GIT_ENV = {
    "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1",
    "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t",
}


def load(path, name):
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


adaptador = load(PLUGIN / "adaptador.py", "adaptador")


class Ambiente(unittest.TestCase):
    """Vault, runtime, repo e um PATH com `freitask` falso; o ambiente que as travas leem."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="oc-travas-")).resolve()
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.vault = self.tmp / "vault"
        (self.vault / "projects" / "p" / "tasks").mkdir(parents=True)
        (self.vault / "projects" / "p" / "tasks" / "x.md").write_text("task\n")
        self.runtime = self.tmp / "rt"
        self.runtime.mkdir()
        self.bin = self.tmp / "bin"
        self.bin.mkdir()
        self.freitask(0)
        self.repo = self.tmp / "repo"
        self.repo.mkdir()
        self.git("init", "-q")
        (self.repo / "docs" / "agents").mkdir(parents=True)
        (self.repo / "docs" / "agents" / "verificacao.md").write_text("```portoes\n*  true\n```\n")
        (self.repo / "a.txt").write_text("um\n")
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "base")
        self.env = {
            **os.environ, **GIT_ENV, "TRAVAS_VAULT": str(self.vault), "XDG_RUNTIME_DIR": str(self.runtime),
            "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
        }
        patcher = unittest.mock.patch.dict(os.environ, self.env)
        patcher.start()
        self.addCleanup(patcher.stop)

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.repo), *args], check=True, capture_output=True, text=True,
                              env={**os.environ, **GIT_ENV}).stdout

    def freitask(self, code, out="o doctor achou problema"):
        path = self.bin / "freitask"
        path.write_text("#!/bin/sh\necho '%s'\nexit %d\n" % (out, code))
        path.chmod(0o755)

    def runtime_files(self):
        base = self.runtime / "claude-travas"
        return sorted(p.name for p in base.iterdir()) if base.is_dir() else []


import unittest.mock  # noqa: E402  (depois do `unittest` acima, que o `Ambiente` usa)


class Traducao(unittest.TestCase):
    def calls(self, **request):
        return adaptador.claude_calls({"cwd": "/work", "evento": "antes", **request})

    def test_shell_vira_bash_com_o_workdir_como_cwd(self):
        self.assertEqual(self.calls(ferramenta="shell", entrada={"command": "ls"}), [("Bash", {"command": "ls"}, "/work")])
        got = self.calls(ferramenta="shell", entrada={"command": "ls", "workdir": "sub", "background": True})
        self.assertEqual(got, [("Bash", {"command": "ls", "run_in_background": True}, "/work/sub")])
        got = self.calls(ferramenta="shell", entrada={"command": "ls", "workdir": "/outro"})
        self.assertEqual(got[0][2], "/outro")

    def test_edit_e_write_viram_edit_e_write_com_o_caminho_absoluto(self):
        self.assertEqual(self.calls(ferramenta="edit", entrada={"path": "a/b.txt"}), [("Edit", {"file_path": "/work/a/b.txt"}, "/work")])
        self.assertEqual(self.calls(ferramenta="write", entrada={"path": "/x/y"}), [("Write", {"file_path": "/x/y"}, "/work")])

    def test_patch_vira_um_edit_por_arquivo(self):
        patch = "*** Begin Patch\n*** Add File: novo.md\n+x\n*** Update File: src/a.py\n@@\n*** Delete File: velho\n*** End Patch"
        antes = self.calls(ferramenta="patch", entrada={"patchText": patch})
        self.assertEqual([c[1]["file_path"] for c in antes], ["/work/novo.md", "/work/src/a.py", "/work/velho"])
        self.assertTrue(all(c[0] == "Edit" for c in antes))
        # depois da ferramenta valem os caminhos que ela aplicou
        depois = self.calls(ferramenta="patch", evento="depois", entrada={"patchText": patch},
                            aplicados=[{"type": "add", "resource": "novo.md", "target": "/work/novo.md"}])
        self.assertEqual([c[1]["file_path"] for c in depois], ["/work/novo.md"])

    def test_ferramenta_sem_trava_ou_entrada_torta_nao_chama_nada(self):
        self.assertEqual(self.calls(ferramenta="read", entrada={"path": "a"}), [])
        self.assertEqual(self.calls(ferramenta="shell", entrada="ls"), [])
        self.assertEqual(self.calls(ferramenta="shell", entrada={}), [])
        self.assertEqual(self.calls(ferramenta="edit", entrada={"path": 3}), [])

    def test_o_evento_do_claude_code_de_cada_pedido(self):
        ev = lambda **r: adaptador.hook_event(r)
        self.assertEqual(ev(evento="antes"), "PreToolUse")
        self.assertEqual(ev(evento="depois", status="completed"), "PostToolUse")
        self.assertEqual(ev(evento="depois", status="error"), "PostToolUseFailure")
        self.assertEqual(ev(evento="parar"), "Stop")
        self.assertIsNone(ev(evento="outro"))

    def test_matcher_casa_o_nome_inteiro(self):
        spec = {"PreToolUse": [
            {"matcher": "Bash", "hooks": [{"type": "command", "command": "a"}]},
            {"matcher": "Edit|Write|Bash", "hooks": [{"type": "command", "command": "b", "timeout": 5}]},
            {"hooks": [{"type": "command", "command": "c"}]},
        ]}
        names = lambda tool: [c for c, _ in adaptador.hooks_for(spec, "PreToolUse", tool, "/t")]
        self.assertEqual(names("Bash"), ["a", "b", "c"])
        self.assertEqual(names("Write"), ["b", "c"])
        self.assertEqual(names("NotebookEdit"), ["c"])
        self.assertEqual(adaptador.hooks_for(spec, "PreToolUse", "Edit", "/t")[0][1], 5)
        self.assertEqual(adaptador.hooks_for(spec, "Stop", "Bash", "/t"), [])


class Despacho(Ambiente):
    """`handle` contra um `travas.json` falso, para o que o adaptador decide sozinho."""

    def spec(self, event, script, matcher=None, timeout=5):
        path = self.tmp / "hook.sh"
        path.write_text("#!/bin/sh\n" + script)
        path.chmod(0o755)
        group = {"hooks": [{"type": "command", "command": "'%s'" % path, "timeout": timeout}]}
        if matcher:
            group["matcher"] = matcher
        return {event: [group]}

    def test_o_hook_recebe_o_json_que_o_claude_code_daria(self):
        spec = self.spec("PreToolUse", "cat > '%s'\n" % (self.tmp / "visto.json"), "Bash")
        adaptador.handle({"evento": "antes", "sessao": "ses_1", "cwd": "/work", "ferramenta": "shell",
                          "entrada": {"command": "ls"}, "chamada": "call_9"}, spec)
        self.assertEqual(json.loads((self.tmp / "visto.json").read_text()), {
            "session_id": "ses_1", "hook_event_name": "PreToolUse", "cwd": "/work",
            "tool_name": "Bash", "tool_input": {"command": "ls"}, "tool_use_id": "call_9",
        })

    def test_o_stop_recebe_stop_hook_active(self):
        spec = self.spec("Stop", "cat > '%s'\n" % (self.tmp / "visto.json"))
        adaptador.handle({"evento": "parar", "sessao": "ses_1", "cwd": "/work", "parada_ativa": True}, spec)
        seen = json.loads((self.tmp / "visto.json").read_text())
        self.assertEqual(seen, {"session_id": "ses_1", "hook_event_name": "Stop", "cwd": "/work", "stop_hook_active": True})

    def test_hook_que_nega_vira_nega_com_o_motivo(self):
        deny = json.dumps({"hookSpecificOutput": {"permissionDecision": "deny", "permissionDecisionReason": "não"}})
        spec = self.spec("PreToolUse", "cat >/dev/null; echo '%s'\n" % deny)
        got = adaptador.handle({"evento": "antes", "sessao": "s", "cwd": "/w", "ferramenta": "shell",
                                "entrada": {"command": "x"}}, spec)
        self.assertEqual(got, {"nega": "não"})

    def test_hook_que_bloqueia_o_stop_vira_bloqueia(self):
        spec = self.spec("Stop", "cat >/dev/null; echo '{\"decision\":\"block\",\"reason\":\"falta isto\"}'\n")
        self.assertEqual(adaptador.handle({"evento": "parar", "sessao": "s", "cwd": "/w"}, spec), {"bloqueia": "falta isto"})

    def test_hook_que_falha_nunca_nega_nem_bloqueia(self):
        for script in ("exit 3\n", "echo nao-e-json\n", "sleep 5\n", "echo '[1]'\n", "echo '{\"decision\":\"block\",\"reason\":\"x\"}'; exit 1\n"):
            with self.subTest(script=script):
                spec = {**self.spec("Stop", script, timeout=1)}
                self.assertEqual(adaptador.handle({"evento": "parar", "sessao": "s", "cwd": "/w"}, spec), {})
        gone = {"Stop": [{"hooks": [{"type": "command", "command": "/nao/existe", "timeout": 1}]}]}
        self.assertEqual(adaptador.handle({"evento": "parar", "sessao": "s", "cwd": "/w"}, gone), {})

    def test_sem_travas_json_ou_sem_sessao_nada_age(self):
        self.assertEqual(adaptador.handle({"evento": "parar", "sessao": "s", "cwd": "/w"}, {}), {})
        self.assertEqual(adaptador.handle({"evento": "parar", "cwd": "/w"}, {"Stop": [{"hooks": []}]}), {})
        self.assertEqual(adaptador.load_spec(str(self.tmp)), {})

    def test_o_script_com_lixo_no_stdin_responde_vazio(self):
        for stdin in ("", "{ nao", "[1]", "null"):
            done = subprocess.run([sys.executable, "-I", str(PLUGIN / "adaptador.py")], input=stdin,
                                  capture_output=True, text=True, env=self.env)
            self.assertEqual((done.returncode, json.loads(done.stdout)), (0, {}), stdin)

    def test_o_travas_json_do_repo_carrega_com_as_tres_travas(self):
        spec = adaptador.load_spec()
        commands = {c for event in spec.values() for group in event for h in group["hooks"] for c in [h["command"]]}
        for trava in ("tasks-so-pelo-freitask", "verificacao-no-stop", "doctor-no-stop"):
            self.assertTrue(any(trava in c for c in commands), trava)
        self.assertFalse(any("${TRAVAS_DIR}" in c for c in commands))
        self.assertEqual(adaptador.TRAVAS_DIR, str(TRAVAS.resolve()))


class TravasDeVerdade(Ambiente):
    """O adaptador contra as travas reais, no ambiente temporário."""

    def ask(self, **request):
        return adaptador.handle({"sessao": "ses_real", "cwd": str(self.repo), **request})

    def test_mv_de_task_do_vault_e_recusado_com_o_motivo_da_trava(self):
        got = self.ask(evento="antes", ferramenta="shell", chamada="c1",
                       entrada={"command": "mv %s/projects/p/tasks/x.md /tmp/y.md" % self.vault})
        self.assertIn("freitask archive", got["nega"])
        self.assertEqual(self.ask(evento="antes", ferramenta="shell", chamada="c2", entrada={"command": "ls"}), {})

    def test_escrever_no_vault_marca_a_sessao_e_o_stop_cobra_o_doctor(self):
        self.ask(evento="depois", status="completed", ferramenta="write",
                 entrada={"path": str(self.vault / "projects" / "p" / "nota.md")})
        self.assertEqual(self.runtime_files(), ["toques-vault-ses_real", "vault-ses_real"])
        self.freitask(1)
        got = self.ask(evento="parar")
        self.assertIn("o doctor achou problema", got["bloqueia"])
        # a segunda passada (a continuação que o próprio Stop pediu) deixa encerrar
        self.assertEqual(self.ask(evento="parar", parada_ativa=True), {})
        self.freitask(0)
        self.assertEqual(self.ask(evento="parar"), {})
        self.assertNotIn("vault-ses_real", self.runtime_files())

    def test_editar_codigo_de_repo_com_verificacao_sem_verificar_o_stop_cobra(self):
        self.ask(evento="antes", ferramenta="edit", chamada="c1", entrada={"path": "a.txt"})
        (self.repo / "a.txt").write_text("dois\n")
        got = self.ask(evento="parar")
        self.assertIn("verificar", got["bloqueia"])
        self.assertIn(str(self.repo), got["bloqueia"])
        # o carimbo da `verificar` (a skill roda isto) tira a cobrança
        subprocess.run([sys.executable, "-I", str(TRAVAS / "verificacao-no-stop"), "carimba", str(self.repo)],
                       check=True, env=self.env)
        self.assertEqual(self.ask(evento="parar"), {})

    def test_patch_conta_como_edicao_de_cada_arquivo(self):
        patch = "*** Begin Patch\n*** Update File: a.txt\n@@\n-um\n+tres\n*** End Patch"
        self.ask(evento="antes", ferramenta="patch", chamada="c1", entrada={"patchText": patch})
        (self.repo / "a.txt").write_text("tres\n")
        self.assertIn(str(self.repo), self.ask(evento="parar")["bloqueia"])

    def test_bash_que_suja_o_repo_entra_na_conta_pelo_antes_e_pelo_depois(self):
        self.ask(evento="antes", ferramenta="shell", chamada="c7", entrada={"command": "echo x > b.txt"})
        (self.repo / "b.txt").write_text("x\n")
        self.ask(evento="depois", status="completed", ferramenta="shell", chamada="c7", entrada={"command": "echo x > b.txt"})
        lists = [p.read_text().split("\n") for p in (self.runtime / "claude-travas").glob("verif-*")]
        self.assertEqual([lines[0] for lines in lists], [str(self.repo)])
        self.assertIn("b.txt", lists[0])

    def test_o_id_gravado_se_acha_pelo_pendente_e_pelo_pendencias(self):
        # o id é o do OpenCode (`ses_...`): o `pendente` das travas e o `pendencias --sessao` o leem igual
        self.ask(evento="depois", status="completed", ferramenta="write",
                 entrada={"path": str(self.vault / "projects" / "p" / "nota.md")})
        self.ask(evento="antes", ferramenta="edit", chamada="c1", entrada={"path": "a.txt"})
        (self.repo / "a.txt").write_text("dois\n")
        run = lambda trava: subprocess.run([sys.executable, "-I", str(TRAVAS / trava), "pendente", "ses_real"],
                                           capture_output=True, text=True, env=self.env).stdout
        self.assertEqual(run("doctor-no-stop"), "vault\n")
        self.assertEqual(run("verificacao-no-stop"), "1\t%s\n" % self.repo)
        pendencias = load(PENDENCIAS, "pendencias")
        self.assertEqual(pendencias.vault_toques("ses_real"), ["arquivo projects/p/nota.md"])
        self.assertEqual(list(pendencias.session_lists("ses_real")), [str(self.repo)])


@unittest.skipUnless(NODE, "node não encontrado: o plugin só se testa com ele")
class Ganchos(Ambiente):
    """`server.ts` com um `ctx` falso: o que cada gancho faz com o adaptador e as travas reais."""

    HARNESS = textwrap.dedent(
        r"""
        import plugin from %(server)s
        const sessions = %(sessions)s
        const hooks = {}
        const synthetic = []
        const skills = %(skills)s
        const ctx = {
          session: {
            get: async ({ sessionID }) => {
              if (!sessions[sessionID]) throw new Error("sumiu")
              return { location: { directory: %(cwd)s }, ...sessions[sessionID] }
            },
            hook: async (name, fn) => { hooks["session." + name] = fn },
            synthetic: async (x) => { synthetic.push(x) },
          },
          tool: { hook: async (name, fn) => { hooks["tool." + name] = fn } },
          skill: { transform: async (fn) => { hooks.skill = () => fn({
            list: () => skills,
            update: (id, up) => up(skills.find((s) => s.id === id)),
          }) } },
        }
        await plugin.setup(ctx)
        const attempt = async (name, event) => {
          try { await hooks[name](event); return null } catch (e) { return String(e.message) }
        }
        let out = null
        %(body)s
        console.log(JSON.stringify({ out, synthetic, skills }))
        """
    )

    def run_plugin(self, body, sessions=None, skills=None, env=None):
        script = self.HARNESS % {
            "server": json.dumps((PLUGIN / "server.ts").as_uri()),
            "cwd": json.dumps(str(self.repo)),
            "sessions": json.dumps(sessions or {"ses_main": {}}),
            "skills": json.dumps(skills or []),
            "body": body,
        }
        done = subprocess.run([NODE, "--no-warnings", "--input-type=module", "-e", script],
                              capture_output=True, text=True, env=env or self.env, timeout=120)
        self.assertEqual(done.returncode, 0, done.stderr)
        return json.loads(done.stdout)

    def test_antes_de_mv_de_task_lanca_o_motivo_da_trava(self):
        got = self.run_plugin(
            """
            const mv = "mv %s/projects/p/tasks/x.md /tmp/y.md"
            out = {
              mv: await attempt("tool.execute.before", { sessionID: "ses_main", tool: "shell", id: "c1", input: { command: mv } }),
              ls: await attempt("tool.execute.before", { sessionID: "ses_main", tool: "shell", id: "c2", input: { command: "ls" } }),
              read: await attempt("tool.execute.before", { sessionID: "ses_main", tool: "read", id: "c3", input: { path: "a" } }),
            }
            """ % self.vault
        )
        self.assertIn("freitask archive", got["out"]["mv"])
        self.assertIsNone(got["out"]["ls"])
        self.assertIsNone(got["out"]["read"])

    def test_stop_cobra_uma_vez_e_a_segunda_passada_deixa_encerrar(self):
        self.freitask(1)
        got = self.run_plugin(
            """
            const base = { sessionID: "ses_main", background: [] }
            await hooks["tool.execute.after"]({ sessionID: "ses_main", tool: "write", id: "c1", status: "completed",
                                                input: { path: "%s/projects/p/nota.md" }, result: {} })
            await hooks["session.experimental.idle"](base)
            await hooks["session.experimental.idle"](base)
            await hooks["session.experimental.idle"](base)
            """ % self.vault
        )
        # cobrou na 1a; a 2a é a continuação (stop_hook_active); a 3a cobra de novo porque a 2a limpou o laço
        self.assertEqual(len(got["synthetic"]), 2)
        self.assertEqual(got["synthetic"][0]["sessionID"], "ses_main")
        self.assertIn("o doctor achou problema", got["synthetic"][0]["text"])

    def test_um_prompt_novo_do_dono_zera_o_laco(self):
        self.freitask(1)
        got = self.run_plugin(
            """
            const base = { sessionID: "ses_main", background: [] }
            await hooks["tool.execute.after"]({ sessionID: "ses_main", tool: "write", id: "c1", status: "completed",
                                                input: { path: "%s/projects/p/nota.md" }, result: {} })
            await hooks["session.experimental.idle"](base)
            await hooks["session.prompt"]({ sessionID: "ses_main" })
            await hooks["session.experimental.idle"](base)
            """ % self.vault
        )
        self.assertEqual(len(got["synthetic"]), 2)

    def test_stop_limpo_nao_manda_nada(self):
        got = self.run_plugin('await hooks["session.experimental.idle"]({ sessionID: "ses_main", background: [] })')
        self.assertEqual(got["synthetic"], [])

    def test_sessao_filha_encerra_sem_cobranca_e_toca_como_a_raiz(self):
        self.freitask(1)
        got = self.run_plugin(
            """
            await hooks["tool.execute.after"]({ sessionID: "ses_filha", tool: "write", id: "c1", status: "completed",
                                                input: { path: "%s/projects/p/nota.md" }, result: {} })
            await hooks["session.experimental.idle"]({ sessionID: "ses_filha", background: [] })
            out = { filha_cobrou: synthetic.length }
            await hooks["session.experimental.idle"]({ sessionID: "ses_main", background: [] })
            """ % self.vault,
            sessions={"ses_main": {}, "ses_filha": {"parentID": "ses_main"}},
        )
        self.assertEqual(got["out"], {"filha_cobrou": 0})
        # o toque da filha foi para a sessão raiz, que é quem o Stop cobra
        self.assertEqual(self.runtime_files(), ["toques-vault-ses_main", "vault-ses_main"])
        self.assertEqual([s["sessionID"] for s in got["synthetic"]], ["ses_main"])

    def test_sessao_com_shell_ou_subagente_em_andamento_nao_cobra(self):
        self.freitask(1)
        got = self.run_plugin(
            """
            await hooks["tool.execute.after"]({ sessionID: "ses_main", tool: "write", id: "c1", status: "completed",
                                                input: { path: "%s/projects/p/nota.md" }, result: {} })
            await hooks["session.experimental.idle"]({ sessionID: "ses_main",
              background: [{ kind: "shell", sessionID: "ses_main", shellID: "s", command: "sleep 9" }] })
            out = synthetic.length
            await hooks["session.experimental.idle"]({ sessionID: "ses_main",
              background: [{ kind: "shell", sessionID: "ses_outra", shellID: "s", command: "sleep 9" }] })
            """ % self.vault
        )
        self.assertEqual(got["out"], 0)
        self.assertEqual(len(got["synthetic"]), 1)

    def test_edicao_de_codigo_sem_verificar_o_stop_cobra_a_verificar(self):
        got = self.run_plugin(
            """
            await hooks["tool.execute.before"]({ sessionID: "ses_main", tool: "edit", id: "c1", input: { path: "a.txt" } })
            await (await import("node:fs/promises")).writeFile(%s, "dois\\n")
            await hooks["session.experimental.idle"]({ sessionID: "ses_main", background: [] })
            """ % json.dumps(str(self.repo / "a.txt"))
        )
        self.assertEqual(len(got["synthetic"]), 1)
        self.assertIn("`verificar`", got["synthetic"][0]["text"])

    def test_depois_de_patch_o_arquivo_aplicado_no_vault_marca_a_sessao(self):
        self.run_plugin(
            """
            await hooks["tool.execute.after"]({ sessionID: "ses_main", tool: "patch", id: "c1", status: "completed",
              input: { patchText: "" }, result: { output: { applied: [{ type: "add", resource: "n", target: %s }] } } })
            """ % json.dumps(str(self.vault / "projects" / "p" / "n.md"))
        )
        self.assertEqual((self.runtime / "claude-travas" / "toques-vault-ses_main").read_text(), "arquivo projects/p/n.md\n")

    def test_sessao_que_nao_se_acha_ou_python_ausente_nao_derruba_nem_recusa(self):
        got = self.run_plugin(
            """
            out = {
              sumida: await attempt("tool.execute.before", { sessionID: "ses_x", tool: "shell", id: "c", input: { command: "mv %s/projects/p/tasks/x.md /tmp" } }),
              idle: await attempt("session.experimental.idle", { sessionID: "ses_x", background: [] }),
            }
            """ % self.vault
        )
        self.assertEqual(got["out"], {"sumida": None, "idle": None})
        sem_python = {**self.env, "PATH": str(self.tmp / "vazio")}
        got = self.run_plugin(
            """
            out = {
              mv: await attempt("tool.execute.before", { sessionID: "ses_main", tool: "shell", id: "c", input: { command: "mv %s/projects/p/tasks/x.md /tmp" } }),
              idle: await attempt("session.experimental.idle", { sessionID: "ses_main", background: [] }),
              depois: await attempt("tool.execute.after", { sessionID: "ses_main", tool: "shell", id: "c", status: "error", input: { command: "ls" } }),
            }
            """ % self.vault,
            env=sem_python,
        )
        self.assertEqual(got["out"], {"mv": None, "idle": None, "depois": None})

    def test_a_skill_com_session_id_do_claude_ganha_a_variavel_do_shell(self):
        skills = [
            {"id": "fechar", "content": "rode `pendencias --sessao ${CLAUDE_SESSION_ID} --plano` e de novo ${CLAUDE_SESSION_ID}"},
            {"id": "outra", "content": "sem o id"},
        ]
        got = self.run_plugin('await hooks["session.prompt"]({ sessionID: "ses_main" })\nhooks.skill()', skills=skills)
        self.assertEqual(got["skills"][0]["content"],
                         "rode `pendencias --sessao $OPENCODE_SESSION_ID --plano` e de novo $OPENCODE_SESSION_ID")
        self.assertEqual(got["skills"][1]["content"], "sem o id")

    def test_a_fechar_do_repo_tem_o_id_so_onde_a_transformacao_alcanca(self):
        skill = PKG / "skills" / "fechar"
        for path in (skill / "SKILL.md", skill / "reference.md"):
            text = path.read_text(encoding="utf-8")
            self.assertEqual("${CLAUDE_SESSION_ID}" in text, path.name == "SKILL.md", path.name)


class Pacote(unittest.TestCase):
    def test_o_setup_linka_cada_diretorio_de_plugins_inclusive_o_das_travas(self):
        done = subprocess.run(
            ["bash", "-c", '. "%s/hooks/lib.sh"; OPENCODE_CONFIG_DIR=/cfg opencode_plugin_links' % PKG],
            capture_output=True, text=True,
        )
        links = dict(line.split("\t") for line in done.stdout.splitlines())
        self.assertEqual(links[str(PLUGIN)], "/cfg/plugins/travas")
        self.assertTrue((PLUGIN / "server.ts").is_file())

    def test_o_ts_nao_importa_o_pacote_do_opencode_em_tempo_de_execucao(self):
        for name in ("server.ts", "travas.ts"):
            text = (PLUGIN / name).read_text(encoding="utf-8")
            runtime_imports = [l for l in text.splitlines() if l.startswith("import ") and not l.startswith("import type")]
            self.assertFalse([l for l in runtime_imports if "@opencode" in l], name)


if __name__ == "__main__":
    unittest.main()
