"""Testes da trava `agents/travas/doctor-no-stop`: o que `written()` registra e o
que o `marca` grava. O script não tem `.py`, então entra por SourceFileLoader."""

import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True  # o script testado não ganha __pycache__ ao lado
SCRIPT = Path(__file__).resolve().parents[1] / "travas" / "doctor-no-stop"


def load():
    loader = importlib.machinery.SourceFileLoader("doctor_no_stop", str(SCRIPT))
    spec = importlib.util.spec_from_loader("doctor_no_stop", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


trava = load()


def bash(command):
    return {"tool_name": "Bash", "tool_input": {"command": command}}


class Written(unittest.TestCase):
    def check(self, command, expected):
        self.assertEqual(trava.written(bash(command)), expected, command)

    def test_move_registra_so_o_id_da_task(self):
        self.check("freitask move foo bar", ["task foo"])
        self.check("freitask move foo bar 2>&1", ["task foo"])

    def test_redirecionamento_nao_e_id_de_task(self):
        self.check("freitask set --help 2>&1", [])
        self.check("freitask set 2>&1", [])

    def test_redirecionamento_no_fim_nao_atrapalha_a_task(self):
        self.check("freitask set foo --status tip 2>&1", ["task foo"])
        self.check("freitask set foo --title 'x' 2>/dev/null", ["task foo"])
        self.check("freitask set foo --title 'x' > /dev/null", ["task foo"])
        self.check("freitask set foo &> /dev/null", ["task foo"])
        self.check("freitask set foo >> log 2>&1", ["task foo"])

    def test_redirecionamento_nao_cola_comandos(self):
        self.check("freitask doctor 2>&1; freitask set a", ["task a"])
        self.check("freitask set a 2>&1 | tail", ["task a"])

    def test_sinal_dentro_de_argumento_entre_aspas_nao_e_redirecionamento(self):
        self.check("freitask set --title 'a > b' foo", ["task foo"])
        self.check("freitask new proj id-x 'Foo <bar>' 2>&1", ["task id-x"])

    def test_outros_verbos_com_redirecionamento(self):
        self.check("freitask new proj id-x 'T' 2>&1", ["task id-x"])
        self.check("freitask rename a b", ["task a", "task b"])
        self.check("freitask doctor 2>&1", [])


class Marca(unittest.TestCase):
    def test_move_marca_a_sessao_e_anota_a_task(self):
        with tempfile.TemporaryDirectory() as vault, tempfile.TemporaryDirectory() as runtime:
            env = {**os.environ, "TRAVAS_VAULT": vault, "XDG_RUNTIME_DIR": runtime}
            event = {"session_id": "sessao-teste", **bash("freitask move foo bar")}
            subprocess.run([sys.executable, "-I", str(SCRIPT), "marca"], input=json.dumps(event),
                           text=True, env=env, check=True)
            base = Path(runtime) / "claude-travas"
            self.assertTrue((base / "vault-sessao-teste").exists())
            self.assertEqual((base / "toques-vault-sessao-teste").read_text(), "task foo\n")


if __name__ == "__main__":
    unittest.main()
