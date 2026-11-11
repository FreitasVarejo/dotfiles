"""Testes do `agents/statusline/claude-subagent-statusline`: uma linha JSON
`{"id", "content"}` por subagente, a cor vinda do frontmatter do agente, o `wt:`
das worktrees e a saída calada para entrada ruim.

O script roda de verdade, com o JSON no stdin. O HOME e o repo do subagente são
diretórios temporários, então nenhum `.claude/agents` real entra na conta."""

import json
import os
import re
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "statusline" / "claude-subagent-statusline"
ANSI = re.compile(r"\x1b\[[0-9;]*m")
GIT_ENV = {
    "GIT_CONFIG_GLOBAL": os.devnull,
    "GIT_CONFIG_NOSYSTEM": "1",
}


def now_ms(seconds_ago=0):
    return int((time.time() - seconds_ago) * 1000)


def agent_file(directory, name, color=None):
    directory.mkdir(parents=True, exist_ok=True)
    lines = ["---", "name: %s" % name, "description: x"]
    if color is not None:
        lines.append("color: %s" % color)
    (directory / (name + ".md")).write_text("\n".join(lines + ["---", "", "corpo", ""]), encoding="utf-8")


class SubagentStatusline(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.home = Path(tmp.name) / "home"
        self.repo = Path(tmp.name) / "repo"
        self.home.mkdir()
        self.repo.mkdir()
        subprocess.run(["git", "-C", str(self.repo), "init", "-q"], check=True, env={**os.environ, **GIT_ENV})

    def run_script(self, stdin):
        env = {**os.environ, **GIT_ENV, "HOME": str(self.home)}
        proc = subprocess.run([str(SCRIPT)], input=stdin, capture_output=True, text=True, env=env)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stderr, "")
        return proc.stdout

    def lines(self, payload):
        out = self.run_script(payload if isinstance(payload, str) else json.dumps(payload))
        return [json.loads(line) for line in out.splitlines()]

    def task(self, **kw):
        base = {"id": "t1", "type": "local_agent", "agentType": "implementador", "status": "running",
                "description": "Corrige o setup", "model": "claude-sonnet-5-5", "tokenCount": 48234,
                "startTime": now_ms(380), "cwd": str(self.repo)}
        base.update(kw)
        return {k: v for k, v in base.items() if v is not None}

    def test_cada_linha_e_json_com_id_e_content(self):
        rows = self.lines({"tasks": [self.task(), self.task(id="t2", agentType="Explore")]})
        self.assertEqual([r["id"] for r in rows], ["t1", "t2"])
        for row in rows:
            self.assertEqual(set(row), {"id", "content"})
            self.assertIsInstance(row["content"], str)

    def test_conteudo_na_ordem_e_separado_por_ponto_medio(self):
        plain = ANSI.sub("", self.lines({"tasks": [self.task()]})[0]["content"])
        self.assertEqual(plain, " implementador · Corrige o setup · sonnet-5-5 · 48.2k · 6m")

    def test_tempo_em_segundos_minutos_e_horas(self):
        for ago, want in ((42, "42s"), (6 * 60 + 5, "6m"), (3600 + 3 * 60 + 5, "1h03")):
            content = ANSI.sub("", self.lines({"tasks": [self.task(startTime=now_ms(ago))]})[0]["content"])
            self.assertTrue(content.endswith(" · " + want), (ago, content))

    def test_cor_vem_do_frontmatter_do_repo_do_subagente(self):
        agent_file(self.repo / ".claude" / "agents", "implementador", "green")
        content = self.lines({"tasks": [self.task()]})[0]["content"]
        self.assertTrue(content.startswith("\x1b[32m implementador\x1b[0m"), repr(content))
        self.assertIn("\x1b[2m · Corrige o setup", content)

    def test_cor_cai_para_o_projeto_da_sessao_e_depois_para_o_home(self):
        project = self.repo.parent / "projeto"
        agent_file(project / ".claude" / "agents", "implementador", "blue")
        payload = {"cwd": str(project), "tasks": [self.task(cwd=str(self.repo.parent))]}
        self.assertTrue(self.lines(payload)[0]["content"].startswith("\x1b[34m"))

        agent_file(self.home / ".claude" / "agents", "implementador", "cyan")
        self.assertTrue(self.lines({"tasks": [self.task()]})[0]["content"].startswith("\x1b[36m"))

    def test_task_sem_cwd_ainda_acha_a_cor_no_projeto_da_sessao(self):
        projeto = self.home.parent / "projeto-sem-git"
        agent_file(projeto / ".claude" / "agents", "implementador", "red")
        agent_file(self.home / ".claude" / "agents", "implementador", "cyan")
        linha = self.lines({"cwd": str(projeto), "tasks": [self.task(cwd=None)]})[0]
        self.assertIn("\x1b[31m", linha["content"])

    def test_descricao_com_quebra_de_linha_vira_uma_linha_so(self):
        linha = self.lines({"tasks": [self.task(description="Corrige\n  o setup")]})[0]
        self.assertIn(" · Corrige o setup · ", ANSI.sub("", linha["content"]))

    def test_repo_vence_o_home(self):
        agent_file(self.repo / ".claude" / "agents", "implementador", "red")
        agent_file(self.home / ".claude" / "agents", "implementador", "cyan")
        self.assertTrue(self.lines({"tasks": [self.task()]})[0]["content"].startswith("\x1b[31m"))

    def test_todos_os_nomes_de_cor_aceitos_tem_codigo(self):
        agents = self.home / ".claude" / "agents"
        for color in ("red", "blue", "green", "yellow", "purple", "orange", "pink", "cyan"):
            agent_file(agents, "implementador", color)
            head = self.lines({"tasks": [self.task(cwd=None)]})[0]["content"]
            self.assertRegex(head, r"^\x1b\[[0-9;]+m", color)

    def test_agente_sem_arquivo_ou_sem_color_sai_sem_cor(self):
        content = self.lines({"tasks": [self.task(agentType="sem-arquivo")]})[0]["content"]
        self.assertTrue(content.startswith(" sem-arquivo"), repr(content))

        agent_file(self.repo / ".claude" / "agents", "implementador")
        content = self.lines({"tasks": [self.task()]})[0]["content"]
        self.assertTrue(content.startswith(" implementador"), repr(content))
        # So o dim do resto da linha: nenhuma outra sequencia de cor.
        self.assertEqual(re.findall(r"\x1b\[[0-9;]*m", content), ["\x1b[2m", "\x1b[0m"])

    def test_icone_pelo_nome_do_tipo(self):
        cases = {"Explore": "", "coletor-web": "", "implementador": "",
                 "rust-implementer": "", "rust-reviewer": "", "auditor": "",
                 "verificador-web": "", "qualquer": ""}
        for agent_type, icon in cases.items():
            content = self.lines({"tasks": [self.task(agentType=agent_type)]})[0]["content"]
            self.assertTrue(ANSI.sub("", content).startswith(icon + " " + agent_type), (agent_type, content))

    def test_wt_so_quando_o_cwd_esta_numa_worktree(self):
        wt = str(self.repo / ".claude" / "worktrees" / "fix-setup")
        self.assertTrue(ANSI.sub("", self.lines({"tasks": [self.task(cwd=wt)]})[0]["content"]).endswith(" · wt:fix-setup"))
        wt_fundo = wt + "/agents/subagents"
        self.assertIn("wt:fix-setup", self.lines({"tasks": [self.task(cwd=wt_fundo)]})[0]["content"])
        self.assertNotIn("wt:", self.lines({"tasks": [self.task()]})[0]["content"])

    def test_campo_ausente_some_sem_separador_sobrando(self):
        content = self.lines({"tasks": [self.task(model=None, tokenCount=None, startTime=None, cwd=None)]})[0]["content"]
        self.assertEqual(ANSI.sub("", content), " implementador · Corrige o setup")

        content = self.lines({"tasks": [{"id": "x", "agentType": "auditor"}]})[0]["content"]
        self.assertEqual(ANSI.sub("", content), " auditor")
        self.assertNotIn("?", content)

    def test_task_sem_agent_type_fica_de_fora_para_manter_a_linha_padrao(self):
        self.assertEqual(self.lines({"tasks": [{"id": "x", "status": "running"}]}), [])
        self.assertEqual(self.lines({"tasks": [self.task(agentType="")]}), [])

    def test_status_diferente_de_running_vai_como_palavra_no_fim(self):
        plain = ANSI.sub("", self.lines({"tasks": [self.task(status="completed")]})[0]["content"])
        self.assertTrue(plain.endswith(" · 6m · completed"), plain)
        plain = ANSI.sub("", self.lines({"tasks": [self.task(status="running")]})[0]["content"])
        self.assertNotIn("running", plain)

    def test_task_sem_id_fica_de_fora_para_manter_a_linha_padrao(self):
        task = self.task()
        del task["id"]
        self.assertEqual(self.lines({"tasks": [task]}), [])

    def test_tasks_vazio_e_entrada_ruim_saem_com_zero_e_sem_traceback(self):
        for stdin in ('{"tasks": []}', "{}", "[]", '{"tasks": 5}', "isto nao e json", "", "{"):
            self.assertEqual(self.run_script(stdin), "", stdin)


if __name__ == "__main__":
    unittest.main()
