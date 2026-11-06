"""Testes da trava `agents/travas/verificacao-no-stop`: o `pendente`, que diz só
lendo o que o Stop cobraria. Roda o script num repo git temporário."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "travas" / "verificacao-no-stop"
SESSION = "sessao-teste"


def git(root, *args):
    subprocess.run(["git", "-C", root, *args], check=True, capture_output=True)


class Pendente(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = os.path.realpath(os.path.join(self.tmp.name, "repo"))
        self.env = {**os.environ, "XDG_RUNTIME_DIR": os.path.join(self.tmp.name, "run"),
                    "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1"}
        adapter = Path(self.root, "docs", "agents", "verificacao.md")
        adapter.parent.mkdir(parents=True)
        adapter.write_text("# Verificação\n")
        Path(self.root, "a.txt").write_text("um\n")
        git(self.root, "init", "-q")
        git(self.root, "-c", "user.name=t", "-c", "user.email=t@t", "add", ".")
        git(self.root, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "base")

    def run_script(self, *args, event=None):
        return subprocess.run([sys.executable, "-I", str(SCRIPT), *args],
                              input=json.dumps(event) if event else "", capture_output=True,
                              text=True, env=self.env, check=True).stdout

    def edit(self, rel, text):
        path = os.path.join(self.root, rel)
        self.run_script("marca", event={"session_id": SESSION, "tool_name": "Write",
                                        "tool_input": {"file_path": path}})
        Path(path).write_text(text)

    def pendente(self):
        return self.run_script("pendente", SESSION)

    def test_sem_toque_nada_pendente(self):
        self.assertEqual(self.pendente(), "")

    def test_arquivo_mudado_sem_carimbo_e_cobrado(self):
        self.edit("a.txt", "dois\n")
        self.edit("b.txt", "novo\n")
        self.assertEqual(self.pendente(), "2\t%s\n" % self.root)

    def test_carimbo_limpa_e_nova_mudanca_volta_a_cobrar(self):
        self.edit("a.txt", "dois\n")
        self.run_script("carimba", self.root)
        self.assertEqual(self.pendente(), "")
        self.edit("a.txt", "três\n")
        self.assertEqual(self.pendente(), "1\t%s\n" % self.root)

    def test_so_le_a_lista(self):
        self.edit("a.txt", "dois\n")
        git(self.root, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qam", "x")
        lists = sorted(Path(self.env["XDG_RUNTIME_DIR"], "claude-travas").glob("verif-*"))
        self.assertTrue(lists)
        before = [p.read_text() for p in lists]
        self.assertEqual(self.pendente(), "")
        self.assertEqual([p.read_text() for p in lists], before)


if __name__ == "__main__":
    unittest.main()
