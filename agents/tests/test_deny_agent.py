"""Testes da categoria `agent` do `agents/permissions/deny.json`: nomes de subagente
que o Claude Code nega com `Agent(<nome>)`. No Cursor ela é pulada de propósito (o
OpenCode tem o teste dele em `test_opencode.py`).

O agent_config roda de verdade (CLI), contra um deny.json e um arquivo de config
temporários."""

import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
PKG = Path(__file__).resolve().parents[1]
CONFIG = PKG / "hooks" / "agent_config.py"
REAL_DENY = PKG / "permissions" / "deny.json"

DENY = {
    "read": ["~/.segredo"],
    "shell": ["env"],
    "edit": ["~/Vault/daily/**"],
    "agent": ["general-purpose"],
}


class DenyAgent(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="deny-agent-"))
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.deny = self.tmp / "deny.json"
        self.deny.write_text(json.dumps(DENY), encoding="utf-8")
        self.settings = self.tmp / "settings.json"
        self.settings.write_text("{}", encoding="utf-8")

    def run_cfg(self, cmd, agent):
        return subprocess.run(
            [sys.executable, "-I", str(CONFIG), cmd, agent, str(self.settings), str(self.deny)],
            capture_output=True, text=True,
        )

    def plan(self, agent):
        out = self.run_cfg("deny-plan", agent)
        self.assertEqual(out.returncode, 0, out.stderr)
        return out.stdout.splitlines()

    def test_claude_gera_agent_com_o_nome(self):
        self.assertIn("Agent(general-purpose)", self.plan("claude"))

    def test_plano_mostra_so_a_adicao_quando_o_resto_ja_esta(self):
        have = [r for r in self.plan("claude") if not r.startswith("Agent(")]
        self.settings.write_text(json.dumps({"permissions": {"deny": have}}), encoding="utf-8")
        self.assertEqual(self.plan("claude"), ["Agent(general-purpose)"])

    def test_apply_grava_a_regra_no_claude(self):
        out = self.run_cfg("deny-apply", "claude")
        self.assertEqual(out.returncode, 0, out.stderr)
        deny = json.loads(self.settings.read_text(encoding="utf-8"))["permissions"]["deny"]
        self.assertIn("Agent(general-purpose)", deny)

    def test_cursor_nao_gera_nada_para_agent(self):
        plan = self.plan("cursor")
        self.assertTrue(plan)  # read, shell e edit seguem valendo
        self.assertFalse([r for r in plan if "general-purpose" in r or r.startswith("Agent")])
        out = self.run_cfg("deny-apply", "cursor")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertNotIn("general-purpose", self.settings.read_text(encoding="utf-8"))

    def test_so_agent_no_deny_json_nao_nega_nada_no_cursor(self):
        self.deny.write_text(json.dumps({"agent": ["general-purpose"]}), encoding="utf-8")
        self.assertEqual(self.run_cfg("deny-plan", "cursor").returncode, 2)
        self.assertEqual(self.run_cfg("deny-plan", "claude").returncode, 0)

    def test_agent_que_nao_e_lista_e_erro_de_repo(self):
        self.deny.write_text(json.dumps({**DENY, "agent": "general-purpose"}), encoding="utf-8")
        self.assertEqual(self.run_cfg("deny-plan", "claude").returncode, 2)

    def test_o_deny_json_do_repo_bloqueia_o_general_purpose(self):
        spec = json.loads(REAL_DENY.read_text(encoding="utf-8"))
        self.assertIn("general-purpose", spec["agent"])
        self.deny.write_text(REAL_DENY.read_text(encoding="utf-8"), encoding="utf-8")
        self.assertIn("Agent(general-purpose)", self.plan("claude"))


if __name__ == "__main__":
    unittest.main()
