"""Testes da função `opencode` de `bash/.bashrc.d/opencode.sh`.

Um HOME sintético traz um `revive` falso (grava os argumentos num log) e o PATH
põe um `opencode` falso na frente (grava os dele). Nada de tmux nem do opencode
de verdade: o que se confere é o que o wrapper manda a cada um."""

import re
import subprocess
import tempfile
import unittest
from pathlib import Path

WRAPPER = Path(__file__).resolve().parents[1] / ".bashrc.d" / "opencode.sh"
ID = r"ses_[0-9a-f]{12}[A-Za-z0-9]{14}"


class OpencodeWrapperTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp())
        revive = cls.tmp / ".config" / "tmux" / "scripts" / "revive"
        revive.parent.mkdir(parents=True)
        revive.write_text('#!/bin/bash\necho "$*" >>"$LOG_REVIVE"\n')
        revive.chmod(0o755)
        fakebin = cls.tmp / "bin"
        fakebin.mkdir()
        falso = fakebin / "opencode"
        falso.write_text('#!/bin/bash\necho "$*" >>"$LOG_OPENCODE"\nexit "${FAKE_RC:-0}"\n')
        falso.chmod(0o755)
        cls.fakebin = fakebin

    @classmethod
    def tearDownClass(cls):
        import shutil

        shutil.rmtree(cls.tmp, ignore_errors=True)

    def rodar(self, *args, pane="%1", rc=0):
        """Roda `opencode <args>` e devolve (rc, linhas do opencode, linhas do revive)."""
        log_o, log_r = self.tmp / "o.log", self.tmp / "r.log"
        log_o.write_text("")
        log_r.write_text("")
        env = {
            "HOME": str(self.tmp),
            "PATH": f"{self.fakebin}:/usr/bin:/bin",
            "LOG_OPENCODE": str(log_o),
            "LOG_REVIVE": str(log_r),
            "FAKE_RC": str(rc),
        }
        if pane:
            env["TMUX_PANE"] = pane
        r = subprocess.run(
            ["bash", "-c", f'source "{WRAPPER}"; opencode "$@"; exit $?', "x", *args],
            env=env, capture_output=True, text=True,
        )
        return r.returncode, log_o.read_text().splitlines(), log_r.read_text().splitlines()

    def test_tela_cheia_sem_args_gera_id_e_standalone(self):
        rc, oc, rv = self.rodar()
        self.assertEqual(rc, 0)
        (cmd,) = oc
        m = re.fullmatch(rf"--standalone -s ({ID})", cmd)
        self.assertTrue(m, cmd)
        self.assertEqual(rv, [f"set opencode --standalone -s {m.group(1)}", "clear"])

    def test_mini_sem_s_gera_id(self):
        _, oc, rv = self.rodar("mini")
        (cmd,) = oc
        m = re.fullmatch(rf"mini --standalone -s ({ID})", cmd)
        self.assertTrue(m, cmd)
        self.assertEqual(rv, [f"set opencode mini --standalone -s {m.group(1)}", "clear"])

    def test_mini_com_s_repassa_o_id(self):
        _, oc, rv = self.rodar("mini", "-s", "ses_abc")
        self.assertEqual(oc, ["mini --standalone -s ses_abc"])
        self.assertEqual(rv, ["set opencode mini --standalone -s ses_abc", "clear"])

    def test_tela_cheia_com_session_igual(self):
        _, oc, rv = self.rodar("--session=ses_abc")
        self.assertEqual(oc, ["--standalone --session=ses_abc"])
        self.assertEqual(rv, ["set opencode --standalone -s ses_abc", "clear"])

    def test_standalone_do_dono_nao_se_repete(self):
        _, oc, rv = self.rodar("--standalone", "-s", "ses_abc")
        self.assertEqual(oc, ["--standalone -s ses_abc"])
        self.assertEqual(rv, ["set opencode --standalone -s ses_abc", "clear"])

    def test_outros_args_seguem_e_o_revive_so_leva_o_id(self):
        _, oc, rv = self.rodar("mini", "--prompt", "oi", "-s", "ses_abc")
        self.assertEqual(oc, ["mini --standalone --prompt oi -s ses_abc"])
        self.assertEqual(rv, ["set opencode mini --standalone -s ses_abc", "clear"])

    def test_pasta_nao_e_subcomando(self):
        _, oc, rv = self.rodar("/tmp")
        (cmd,) = oc
        self.assertTrue(re.fullmatch(rf"--standalone -s {ID} /tmp", cmd), cmd)
        self.assertEqual(len(rv), 2)

    def test_codigo_de_saida_e_do_opencode_e_o_revive_limpa(self):
        rc, _, rv = self.rodar("mini", rc=3)
        self.assertEqual(rc, 3)
        self.assertEqual(rv[-1], "clear")

    def test_passa_direto_sem_revive(self):
        casos = [
            (("run", "oi"), "run oi"),
            (("session", "list"), "session list"),
            (("auth", "login"), "auth login"),
            (("-c",), "-c"),
            (("mini", "--continue"), "mini --continue"),
            (("mini", "--fork", "-s", "ses_abc"), "mini --fork -s ses_abc"),
            (("--server", "http://x"), "--server http://x"),
            (("--server=http://x", "-s", "ses_abc"), "--server=http://x -s ses_abc"),
            (("--version",), "--version"),
            (("mini", "--help"), "mini --help"),
        ]
        for args, esperado in casos:
            with self.subTest(args=args):
                _, oc, rv = self.rodar(*args)
                self.assertEqual(oc, [esperado])
                self.assertEqual(rv, [])

    def test_fora_do_tmux_nao_muda_nada(self):
        for args, esperado in ((("mini",), "mini"), ((), "")):
            with self.subTest(args=args):
                _, oc, rv = self.rodar(*args, pane="")
                self.assertEqual(oc, [esperado])
                self.assertEqual(rv, [])


if __name__ == "__main__":
    unittest.main()
