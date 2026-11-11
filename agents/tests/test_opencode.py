"""Testes do alvo `opencode` do `agents/hooks/agent_config.py` (ADR 0046): o plano e a
aplicação no opencode.json, a tradução do deny.json em `policies`, a tradução dos
subagentes e o comando gerado por skill. O lib.sh, o setup.sh e o check.sh ficam em
`test_opencode_setup.py`.

O agent_config roda de verdade (CLI, com o status de saída), contra um pacote
`agents/` montado num diretório temporário e um diretório de config temporário. O
HOME também é temporário: nada do $HOME real entra na conta."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[2]
PKG = REPO / "agents"
CONFIG = PKG / "hooks" / "agent_config.py"
MARK = "<!-- gerado por agents/hooks/agent_config.py a partir de "

FRAGMENT = {
    "share": "disabled",
    "permissions": [
        {"action": "read", "resource": "*", "effect": "allow"},
        {"action": "grep", "resource": "*", "effect": "allow"},
        {"action": "shell", "resource": "*", "effect": "ask"},
        {"action": "edit", "resource": "*", "effect": "ask"},
        {"action": "shell", "resource": "git status *", "effect": "allow"},
        {"action": "shell", "resource": "${HOME}/.claude/skills/*/scripts/*", "effect": "allow"},
    ],
    "policies": [{"action": "tool.use", "resource": "read:*canario", "effect": "deny"}],
}
DENY = {
    "read": ["~/.segredo", "~/dev/gmail/dados/**"],
    "shell": ["env", "printenv:*", "gh auth token"],
    "edit": ["~/Vault/daily/**", "~/Vault/**/*.conflict-*"],
    "agent": ["general-purpose"],
}
AUDITOR = '''---
name: auditor
description: "Audita só lendo: \\"nada\\" de edição."
model: inherit
tools: Read, Grep, Bash
color: yellow
---
Você audita.
'''
IMPLEMENTADOR = '''---
name: implementador
description: Escreve código decidido.
model: sonnet
disallowedTools: Agent, Write
color: green
---
Você implementa.
'''


def skill_md(name, front="", body="Corpo."):
    return "---\nname: %s\ndescription: Faz %s.\n%s---\n%s\n" % (name, name, front, body)


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


class Fixture(unittest.TestCase):
    """Pacote `agents/` mínimo e config vazia, ambos temporários."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="oc-test-"))
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.home = self.tmp / "home"
        self.home.mkdir()
        self.pkg = self.tmp / "repo" / "agents"
        self.cfg = self.tmp / "config" / "opencode"
        write(self.pkg / "instructions" / "user.md", "# usuário\n")
        write(self.pkg / "permissions" / "deny.json", json.dumps(DENY))
        write(self.pkg / "opencode" / "config.json", json.dumps(FRAGMENT))
        write(self.pkg / "subagents" / "auditor.md", AUDITOR)
        write(self.pkg / "subagents" / "Implementador.md", IMPLEMENTADOR)
        write(self.pkg / "skills" / "plain" / "SKILL.md", skill_md("plain"))
        write(self.pkg / "skills" / "forked" / "SKILL.md", skill_md("forked", "context: fork\n"))
        write(self.pkg / "skills" / "manual" / "SKILL.md", skill_md("manual", "disable-model-invocation: true\n"))
        write(self.pkg / "skills" / "args" / "SKILL.md", skill_md("args", body="Pedido: $ARGUMENTS"))
        write(self.pkg / "skills" / "session" / "SKILL.md",
              skill_md("session", "disable-model-invocation: true\n", "id ${CLAUDE_SESSION_ID}"))
        self.cfg.mkdir(parents=True)

    def run_cfg(self, cmd, machine="wsl-trabalho"):
        env = {**os.environ, "HOME": str(self.home)}
        return subprocess.run(
            [sys.executable, "-I", str(CONFIG), cmd, str(self.cfg), str(self.pkg), machine],
            capture_output=True, text=True, env=env,
        )

    def plan(self, **kw):
        out = self.run_cfg("opencode-plan", **kw)
        self.assertEqual(out.returncode, 0, out.stderr)
        return dict(line.split("\t") for line in out.stdout.splitlines())

    def apply(self, **kw):
        out = self.run_cfg("opencode-apply", **kw)
        self.assertEqual(out.returncode, 0, out.stderr)
        return dict(line.split("\t") for line in out.stdout.splitlines())

    def config(self):
        return json.loads((self.cfg / "opencode.json").read_text(encoding="utf-8"))

    def put_config(self, data):
        write(self.cfg / "opencode.json", json.dumps(data))

    def snapshot(self):
        return {str(p): (p.stat().st_mtime_ns, p.stat().st_ino) for p in self.cfg.rglob("*") if p.is_file()}


class PlanEApply(Fixture):
    def test_o_plano_acusa_o_que_falta_e_nao_grava(self):
        plan = self.plan()
        self.assertEqual({k: v for k, v in plan.items() if "/" not in k},
                         {"share": "add", "instructions": "add", "permissions": "add", "policies": "add"})
        self.assertEqual(plan["agents/auditor.md"], "add")
        self.assertEqual(plan["commands/forked.md"], "add")
        self.assertEqual(list(self.cfg.iterdir()), [])

    def test_a_aplicacao_grava_e_a_segunda_nao_reescreve_nada(self):
        planned = self.plan()
        self.assertEqual(self.apply(), planned)  # a aplicação faz exatamente o que o plano disse
        self.assertEqual(self.plan(), {})
        before = self.snapshot()
        self.assertEqual(self.apply(), {})
        self.assertEqual(self.snapshot(), before)

    def test_o_opencode_json_leva_o_que_o_repo_declara(self):
        self.apply()
        data = self.config()
        self.assertEqual(data["share"], "disabled")
        self.assertEqual(data["instructions"], [str(self.pkg / "instructions" / "user.md")])
        self.assertEqual(data["permissions"][-1],
                         {"action": "shell", "resource": str(self.home) + "/.claude/skills/*/scripts/*", "effect": "allow"})
        self.assertEqual(data["permissions"], self.expected_permissions())

    def expected_permissions(self):
        text = json.dumps(FRAGMENT["permissions"]).replace("${HOME}", str(self.home))
        return json.loads(text)

    def test_instrucao_da_maquina_so_entra_se_o_arquivo_existir(self):
        self.apply()
        self.assertEqual(len(self.config()["instructions"]), 1)
        write(self.pkg / "instructions" / "machines" / "wsl-trabalho.md", "# wsl\n")
        self.assertEqual(self.plan()["instructions"], "update")
        self.apply()
        self.assertEqual(self.config()["instructions"],
                         [str(self.pkg / "instructions" / "user.md"),
                          str(self.pkg / "instructions" / "machines" / "wsl-trabalho.md")])

    def test_o_que_a_maquina_tem_a_mais_fica_e_o_share_do_repo_vence(self):
        self.put_config({
            "share": "auto", "theme": "x", "instructions": ["/minha/regra.md"],
            "permissions": [{"action": "shell", "resource": "make *", "effect": "allow"}],
            "policies": [{"action": "tool.use", "resource": "shell:rm *", "effect": "deny"}],
        })
        self.assertEqual(self.plan()["share"], "update")
        self.apply()
        data = self.config()
        self.assertEqual((data["share"], data["theme"]), ("disabled", "x"))
        self.assertEqual(data["instructions"][0], "/minha/regra.md")
        self.assertEqual(data["permissions"][0]["resource"], "make *")
        self.assertEqual(data["policies"][0]["resource"], "shell:rm *")

    def test_bloco_do_repo_vai_contiguo_para_o_fim_na_ordem_do_repo(self):
        block = self.expected_permissions()
        mine = {"action": "shell", "resource": "make *", "effect": "allow"}
        # item do repo fora de ordem e um item da máquina no meio e depois do bloco
        self.put_config({"permissions": [block[3], mine, *block[:3], *block[4:], mine]})
        self.assertEqual(self.plan()["permissions"], "update")
        self.apply()
        perms = self.config()["permissions"]
        self.assertEqual(perms[-len(block):], block)
        self.assertEqual(perms[:-len(block)], [mine, mine])
        self.assertNotIn("permissions", self.plan())

    def test_bloco_ja_contiguo_no_fim_nao_mexe(self):
        extra = {"action": "shell", "resource": "make *", "effect": "allow"}
        self.apply()
        data = self.config()
        data["permissions"].insert(0, extra)
        data["policies"].insert(0, {"action": "tool.use", "resource": "shell:rm *", "effect": "deny"})
        self.put_config(data)
        self.assertEqual(self.plan(), {})
        before = self.snapshot()
        self.apply()
        self.assertEqual(self.snapshot(), before)

    def test_deny_de_uma_regra_a_menos_e_acusado(self):
        self.apply()
        data = self.config()
        data["policies"].pop(0)
        self.put_config(data)
        self.assertEqual(self.plan(), {"policies": "update"})
        self.apply()
        self.assertEqual(self.plan(), {})

    def test_so_opencode_jsonc_avisa_e_nao_grava_o_json(self):
        write(self.cfg / "opencode.jsonc", "{ // meu\n}\n")
        self.assertEqual(self.plan()["opencode.jsonc"], "blocked")
        self.assertNotIn("share", self.plan())
        self.apply()
        self.assertFalse((self.cfg / "opencode.json").exists())
        self.assertTrue((self.cfg / "agents" / "auditor.md").exists())  # o resto segue

    def test_opencode_json_ilegivel_e_erro_3_e_nada_e_gravado(self):
        write(self.cfg / "opencode.json", "{ nao e json")
        out = self.run_cfg("opencode-apply")
        self.assertEqual(out.returncode, 3)
        self.assertIn("ilegível", out.stderr)
        self.assertEqual((self.cfg / "opencode.json").read_text(), "{ nao e json")
        self.assertFalse((self.cfg / "agents").exists())

    def test_chave_do_agente_com_tipo_errado_e_erro_3(self):
        self.put_config({"permissions": {"a": 1}})
        self.assertEqual(self.run_cfg("opencode-plan").returncode, 3)

    def test_symlink_do_opencode_json_e_escrito_no_alvo(self):
        real = write(self.tmp / "outro" / "opencode.json", "{}")
        (self.cfg / "opencode.json").symlink_to(real)
        self.apply()
        self.assertTrue((self.cfg / "opencode.json").is_symlink())
        self.assertEqual(json.loads(real.read_text())["share"], "disabled")

    def test_fragmento_invalido_e_erro_2(self):
        for bad in ("{ nao", json.dumps({"mcp": {}}), json.dumps({"share": "disabled", "permissions": [{"action": "x"}]})):
            write(self.pkg / "opencode" / "config.json", bad)
            self.assertEqual(self.run_cfg("opencode-plan").returncode, 2, bad)


class DenyEmPolicies(Fixture):
    def policies(self):
        self.apply()
        return [p["resource"] for p in self.config()["policies"]]

    def test_caminho_vira_curinga_mais_o_caminho_sem_til(self):
        res = self.policies()
        self.assertIn("read:*.segredo", res)
        self.assertIn("read:*dev/gmail/dados/*", res)
        self.assertIn("edit:*Vault/daily/*", res)

    def test_dois_asteriscos_com_barra_casam_tambem_sem_pasta_no_meio(self):
        res = self.policies()
        self.assertIn("edit:*Vault/*/*.conflict-*", res)
        self.assertIn("edit:*Vault/*.conflict-*", res)

    def test_shell_segue_a_semantica_do_deny_json(self):
        res = self.policies()
        self.assertIn("shell:env", res)  # exato
        self.assertIn("shell:printenv *", res)  # prefixo, com e sem argumento
        self.assertIn("shell:gh auth token", res)

    def test_todas_sao_tool_use_deny_e_o_canario_do_fragmento_vem_por_ultimo(self):
        self.apply()
        pols = self.config()["policies"]
        self.assertTrue(all(p["action"] == "tool.use" and p["effect"] == "deny" for p in pols))
        self.assertEqual(pols[-1]["resource"], "read:*canario")

    def test_casa_o_absoluto_e_o_relativo_a_partir_do_til(self):
        import re

        def match(resource, text):  # o Wildcard do OpenCode: "*" -> ".*", ancorado
            pattern = re.escape(resource).replace(r"\*", ".*")
            return re.fullmatch(pattern, text) is not None

        res = self.policies()
        by_action = lambda a: [r.split(":", 1)[1] for r in res if r.startswith(a + ":")]
        hit = lambda a, text: any(match(p, text) for p in by_action(a))
        self.assertTrue(hit("read", "/home/x/.segredo"))
        self.assertTrue(hit("read", ".segredo"))
        self.assertTrue(hit("read", "/home/x/dev/gmail/dados/a/b.csv"))
        self.assertTrue(hit("edit", "/home/x/Vault/daily/2026-01-01.md"))
        self.assertTrue(hit("edit", "/home/x/Vault/n.conflict-1.md"))
        self.assertTrue(hit("edit", "/home/x/Vault/p/n.conflict-1.md"))
        self.assertFalse(hit("read", "/home/x/outra-coisa"))
        self.assertFalse(hit("edit", "/home/x/Vault/nota.md"))

    def test_categoria_agent_e_pulada_sem_erro(self):
        self.apply()
        pols = self.config()["policies"]
        self.assertFalse([p for p in pols if "general-purpose" in p["resource"] or "Agent" in p["resource"]])
        self.assertEqual(self.run_cfg("opencode-plan").returncode, 0)

    def test_deny_json_invalido_e_erro_2(self):
        write(self.pkg / "permissions" / "deny.json", json.dumps({"read": [], "shell": [], "edit": []}))
        self.assertEqual(self.run_cfg("opencode-plan").returncode, 2)
        write(self.pkg / "permissions" / "deny.json", "{ nao")
        self.assertEqual(self.run_cfg("opencode-plan").returncode, 2)


class Subagentes(Fixture):
    def agent(self, name):
        self.apply()
        return (self.cfg / "agents" / (name + ".md")).read_text(encoding="utf-8")

    def front(self, name):
        text = self.agent(name)
        return text.split("---\n")[1]

    def perms(self, name):
        return [json.loads(l[4:]) for l in self.front(name).splitlines() if l.startswith("  - {")]

    def test_id_do_arquivo_em_minusculas_sem_chave_name(self):
        self.apply()
        self.assertTrue((self.cfg / "agents" / "implementador.md").exists())
        self.assertNotIn("name:", self.front("auditor"))
        self.assertIn("mode: subagent", self.front("auditor"))

    def test_so_chaves_do_schema_do_opencode(self):
        keys = {l.split(":")[0] for l in self.front("auditor").splitlines() if l and not l.startswith(" ")}
        self.assertLessEqual(keys, {"description", "mode", "model", "color", "permissions"})

    def test_descricao_com_aspas_sobrevive_ao_yaml(self):
        self.assertIn('description: "Audita só lendo: \\"nada\\" de edição."', self.front("auditor"))

    def test_tools_nega_tudo_e_devolve_as_regras_do_padrao_por_acao(self):
        perms = self.perms("auditor")
        self.assertEqual(perms[0], {"action": "*", "resource": "*", "effect": "deny"})
        self.assertEqual(perms[1:], [
            {"action": "read", "resource": "*", "effect": "allow"},
            {"action": "grep", "resource": "*", "effect": "allow"},
            {"action": "shell", "resource": "*", "effect": "ask"},
            {"action": "shell", "resource": "git status *", "effect": "allow"},
            {"action": "shell", "resource": str(self.home) + "/.claude/skills/*/scripts/*", "effect": "allow"},
            {"action": "external_directory", "resource": "*", "effect": "ask"},
        ])

    def test_acao_sem_regra_no_padrao_e_liberada_menos_external_directory(self):
        write(self.pkg / "subagents" / "coleta.md",
              AUDITOR.replace("Read, Grep, Bash", "WebFetch, WebSearch").replace("auditor", "coleta"))
        perms = self.perms("coleta")
        self.assertEqual(perms[1:], [
            {"action": "webfetch", "resource": "*", "effect": "allow"},
            {"action": "websearch", "resource": "*", "effect": "allow"},
            {"action": "external_directory", "resource": "*", "effect": "ask"},
        ])

    def test_disallowed_tools_vira_deny_de_cada_acao(self):
        self.assertEqual(self.perms("implementador"), [
            {"action": "subagent", "resource": "*", "effect": "deny"},
            {"action": "edit", "resource": "*", "effect": "deny"},
        ])

    def test_traducao_dos_nomes(self):
        names = "Read, Grep, Glob, Bash, Edit, Write, NotebookEdit, WebFetch, WebSearch, Agent, Skill, TodoWrite"
        write(self.pkg / "subagents" / "todos.md", AUDITOR.replace("Read, Grep, Bash", names))
        actions = [p["action"] for p in self.perms("todos")]
        self.assertEqual(sorted(set(actions)), sorted({
            "*", "read", "grep", "glob", "shell", "edit", "webfetch", "websearch",
            "subagent", "skill", "todowrite", "external_directory"}))

    def test_ferramenta_sem_traducao_e_erro_do_repo(self):
        write(self.pkg / "subagents" / "auditor.md", AUDITOR.replace("Read, Grep, Bash", "Read, Teleport"))
        out = self.run_cfg("opencode-apply")
        self.assertEqual(out.returncode, 2)
        self.assertIn("Teleport", out.stderr)
        self.assertFalse((self.cfg / "agents").exists())
        write(self.pkg / "subagents" / "auditor.md", AUDITOR.replace("tools: Read, Grep, Bash", "disallowedTools: Agent, Mcp"))
        self.assertEqual(self.run_cfg("opencode-plan").returncode, 2)

    def test_cor_vira_hex_e_fora_do_mapa_e_erro_do_repo(self):
        self.assertIn('color: "#EAB308"', self.front("auditor"))
        write(self.pkg / "subagents" / "auditor.md", AUDITOR.replace("yellow", "magenta"))
        out = self.run_cfg("opencode-plan")
        self.assertEqual(out.returncode, 2)
        self.assertIn("magenta", out.stderr)

    def test_model_inherit_nao_leva_model(self):
        write(self.cfg / "modelos.json", json.dumps({"opus": "github-copilot/o", "sonnet": "github-copilot/s"}))
        self.assertNotIn("model:", self.front("auditor"))

    def test_model_vem_do_mapa_da_maquina(self):
        write(self.cfg / "modelos.json", json.dumps({"sonnet": "github-copilot/claude-sonnet-4.5"}))
        self.assertIn('model: "github-copilot/claude-sonnet-4.5"', self.front("implementador"))

    def test_sem_mapa_ou_sem_a_chave_o_subagente_sai_sem_model(self):
        self.assertNotIn("model:", self.front("implementador"))
        write(self.cfg / "modelos.json", json.dumps({"haiku": "github-copilot/h"}))
        self.assertEqual(self.plan(), {})  # a chave que falta não muda o gerado

    def test_mapa_ilegivel_ou_malformado_e_erro_3(self):
        write(self.cfg / "modelos.json", "{ nao")
        self.assertEqual(self.run_cfg("opencode-plan").returncode, 3)
        write(self.cfg / "modelos.json", json.dumps({"sonnet": "sem-barra"}))
        self.assertEqual(self.run_cfg("opencode-plan").returncode, 3)

    def test_model_fora_de_inherit_e_dos_apelidos_e_erro_do_repo(self):
        write(self.pkg / "subagents" / "auditor.md", AUDITOR.replace("inherit", "gpt-9"))
        self.assertEqual(self.run_cfg("opencode-plan").returncode, 2)

    def test_marcador_e_corpo(self):
        text = self.agent("auditor")
        self.assertIn(MARK + "agents/subagents/auditor.md; não edite -->\n\nVocê audita.\n", text)

    def test_mudar_o_mapa_atualiza_o_gerado(self):
        self.apply()
        write(self.cfg / "modelos.json", json.dumps({"sonnet": "github-copilot/s"}))
        self.assertEqual(self.plan(), {"agents/implementador.md": "update"})


class ArquivosGerados(Fixture):
    def test_fonte_que_sumiu_leva_o_gerado_embora(self):
        self.apply()
        (self.pkg / "subagents" / "auditor.md").unlink()
        shutil.rmtree(self.pkg / "skills" / "forked")
        self.assertEqual(self.plan(), {"agents/auditor.md": "remove", "commands/forked.md": "remove"})
        self.apply()
        self.assertFalse((self.cfg / "agents" / "auditor.md").exists())
        self.assertFalse((self.cfg / "commands" / "forked.md").exists())
        self.assertTrue((self.cfg / "agents" / "implementador.md").exists())

    def test_arquivo_sem_marcador_nunca_se_toca(self):
        mine = write(self.cfg / "agents" / "auditor.md", "feito à mão\n")
        orphan = write(self.cfg / "commands" / "meu.md", "feito à mão\n")
        self.assertEqual(self.plan()["agents/auditor.md"], "skip")
        self.assertEqual(self.apply()["agents/auditor.md"], "skip")
        self.assertEqual(mine.read_text(), "feito à mão\n")
        self.assertEqual(orphan.read_text(), "feito à mão\n")
        self.assertNotIn("commands/meu.md", self.plan())

    def test_symlink_no_lugar_de_um_gerado_nao_se_toca(self):
        target = write(self.tmp / "fora.md", "dele\n")
        (self.cfg / "agents").mkdir()
        (self.cfg / "agents" / "auditor.md").symlink_to(target)
        self.assertEqual(self.apply()["agents/auditor.md"], "skip")
        self.assertEqual(target.read_text(), "dele\n")

    def test_symlink_com_marcador_nao_e_removido_como_orfao(self):
        target = write(self.tmp / "fora.md", MARK + "x; não edite -->\n")
        (self.cfg / "commands").mkdir()
        (self.cfg / "commands" / "velho.md").symlink_to(target)
        self.assertNotIn("commands/velho.md", self.apply())

    def test_gerado_editado_a_mao_e_reescrito(self):
        self.apply()
        agent = self.cfg / "agents" / "auditor.md"
        agent.write_text(agent.read_text() + "lixo\n")
        self.assertEqual(self.plan(), {"agents/auditor.md": "update"})


class ComandoPorSkill(Fixture):
    def commands(self):
        self.apply()
        return sorted(p.stem for p in (self.cfg / "commands").glob("*.md"))

    def test_quem_ganha_comando(self):
        # fork, só-manual e $ARGUMENTS ganham; a comum e a que usa ${CLAUDE_SESSION_ID} não
        self.assertEqual(self.commands(), ["args", "forked", "manual"])

    def test_session_id_em_qualquer_arquivo_da_skill_exclui(self):
        write(self.pkg / "skills" / "forked" / "scripts" / "x", "echo ${CLAUDE_SESSION_ID}\n")
        self.assertEqual(self.commands(), ["args", "manual"])

    def test_fork_vira_subagent_true_e_os_outros_nao(self):
        self.apply()
        read = lambda n: (self.cfg / "commands" / (n + ".md")).read_text(encoding="utf-8")
        self.assertIn("\nsubagent: true\n", read("forked"))
        self.assertNotIn("subagent", read("manual"))
        self.assertNotIn("subagent", read("args"))

    def test_molde_manda_carregar_a_skill_e_passa_os_argumentos(self):
        self.apply()
        text = (self.cfg / "commands" / "args.md").read_text(encoding="utf-8")
        self.assertIn("description: \"Faz args.\"", text)
        self.assertIn("skill `args`", text)
        self.assertIn("$ARGUMENTS", text)
        self.assertIn(MARK + "agents/skills/args/SKILL.md; não edite -->", text)
        # o OpenCode executa !`cmd` e troca $1..$9 no molde: o gerado não tem nenhum
        self.assertNotIn("!`", text)

    def test_description_ausente_e_erro_do_repo(self):
        write(self.pkg / "skills" / "args" / "SKILL.md", "---\nname: args\n---\n$ARGUMENTS\n")
        self.assertEqual(self.run_cfg("opencode-plan").returncode, 2)

    def test_colide_com_comando_a_mao_e_erro_do_repo(self):
        write(self.pkg / "opencode" / "commands" / "args.md", "x\n")
        self.assertEqual(self.run_cfg("opencode-plan").returncode, 2)


class PacoteReal(unittest.TestCase):
    """O pacote de verdade traduz sem erro, e o que gera obedece ao schema do OpenCode."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="oc-real-"))
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

    def apply(self):
        env = {**os.environ, "HOME": str(self.tmp)}
        out = subprocess.run(
            [sys.executable, "-I", str(CONFIG), "opencode-apply", str(self.tmp / "oc"), str(PKG), "qualquer"],
            capture_output=True, text=True, env=env,
        )
        self.assertEqual(out.returncode, 0, out.stderr)

    def test_todos_os_subagentes_e_a_fechar_fora(self):
        self.apply()
        agents = sorted(p.stem for p in (self.tmp / "oc" / "agents").glob("*.md"))
        self.assertEqual(agents, sorted(p.stem.lower() for p in (PKG / "subagents").glob("*.md")))
        commands = {p.stem for p in (self.tmp / "oc" / "commands").glob("*.md")}
        self.assertNotIn("fechar", commands)
        self.assertIn("verificar", commands)
        forked = (self.tmp / "oc" / "commands" / "verificar.md").read_text(encoding="utf-8")
        self.assertIn("\nsubagent: true\n", forked)

    def test_nada_gerado_tem_chave_fora_do_schema_do_agente(self):
        self.apply()
        for path in (self.tmp / "oc" / "agents").glob("*.md"):
            front = path.read_text(encoding="utf-8").split("---\n")[1]
            keys = {l.split(":")[0] for l in front.splitlines() if l and not l.startswith(" ")}
            self.assertLessEqual(keys, {"description", "mode", "model", "color", "permissions"}, path.name)
            self.assertIn("mode: subagent", front)

    def test_o_fragmento_do_repo_traz_o_canario_e_o_share(self):
        data = json.loads((PKG / "opencode" / "config.json").read_text(encoding="utf-8"))
        self.assertEqual(data["share"], "disabled")
        self.assertIn("read:*canario-do-deny-opencode", [p["resource"] for p in data["policies"]])
        self.apply()

    def test_comandos_a_mao_nao_executam_nem_trocam_nada_sem_querer(self):
        # shellRegex !`...` e $1..$9 são avaliados pelo OpenCode no molde do comando
        import re
        for path in (PKG / "opencode" / "commands").glob("*.md"):
            text = path.read_text(encoding="utf-8")
            self.assertIsNone(re.search(r"!`", text), path.name)
            self.assertIsNone(re.search(r"\$[1-9]", text), path.name)
            self.assertTrue(text.startswith("---\ndescription: "), path.name)


if __name__ == "__main__":
    unittest.main()
