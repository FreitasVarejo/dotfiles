"""Testes do alvo `opencode` no lib.sh, no setup.sh e no check.sh do pacote (ADR 0046):
só o OpenCode 2.x é alvo, a omissão sem ele não cria nada, e com ele o check acusa o
que falta, o setup aplica e a segunda aplicação não reescreve arquivo.

O OpenCode 2.x é um `opencode` falso no PATH, o PATH não tem `claude` (o setup não
registra MCP nem mexe no settings) e o HOME e o diretório de config são temporários:
nada do $HOME real entra na conta."""

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
PKG = Path(__file__).resolve().parents[1]


class Base(unittest.TestCase):
    """Um `opencode` falso, HOME temporário e os hooks do pacote (sem testes próprios)."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="oc-bash-"))
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.home = self.tmp / "home"
        self.home.mkdir()
        self.cfg = self.tmp / "cfg"
        self.fake = self.tmp / "fake"
        self.fake.mkdir()

    def fake_opencode(self, version):
        path = self.fake / "opencode"
        path.write_text("#!/bin/sh\necho '%s'\n" % version)
        path.chmod(0o755)

    def env(self, with_opencode=True):
        # sem `claude` no PATH: o setup não registra MCP nem mexe no settings do HOME temporário
        dirs = [d for d in os.environ["PATH"].split(":") if d and not os.path.exists(os.path.join(d, "claude"))
                and not os.path.exists(os.path.join(d, "opencode"))]
        path = ":".join(([str(self.fake)] if with_opencode else []) + dirs)
        env = {k: v for k, v in os.environ.items() if k not in ("XDG_CONFIG_HOME", "OPENCODE_CONFIG_DIR")}
        env.update(HOME=str(self.home), PATH=path, OPENCODE_CONFIG_DIR=str(self.cfg), AGENTS_MACHINE="wsl-trabalho")
        return env

    def sh(self, script, **kw):
        return subprocess.run(["bash", "-c", script], capture_output=True, text=True, env=self.env(**kw))

    def hook(self, name, **kw):
        return subprocess.run(["bash", str(PKG / "hooks" / name)], capture_output=True, text=True, env=self.env(**kw))


class Bash(Base):
    """lib.sh, setup.sh e check.sh do pacote contra o repo."""

    def active(self, **kw):
        return self.sh('. "%s/hooks/lib.sh"; opencode_active' % PKG, **kw).returncode == 0

    def test_so_o_2x_e_alvo(self):
        self.fake_opencode("2.2.7")
        self.assertTrue(self.active())
        self.fake_opencode("opencode v2.2.7")  # o formato real do 2.x
        self.assertTrue(self.active())
        self.fake_opencode("1.19.5")
        self.assertFalse(self.active())
        self.fake_opencode("12.0.0")
        self.assertFalse(self.active())
        self.assertFalse(self.active(with_opencode=False))

    def test_sem_2x_o_setup_omite_e_nao_cria_nada(self):
        self.fake_opencode("1.19.5")
        out = self.hook("setup.sh")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("1.19.5 não é 2.x", out.stdout)
        self.assertFalse(self.cfg.exists())
        out = self.hook("setup.sh", with_opencode=False)
        self.assertIn("OpenCode não encontrado", out.stdout)
        self.assertFalse(self.cfg.exists())

    def test_sem_2x_o_check_omite_e_nao_fica_vermelho_por_causa_dele(self):
        self.fake_opencode("1.19.5")
        out = self.hook("check.sh")
        self.assertIn("Sem OpenCode 2.x: alvo opencode não verificado", out.stdout)
        self.assertNotIn("opencode:", out.stdout)

    def test_com_2x_o_check_acusa_o_setup_aplica_e_o_check_fecha(self):
        self.fake_opencode("2.2.7")
        self.hook("setup.sh", with_opencode=False)  # só as skills e o resto, sem o alvo
        red = self.hook("check.sh")
        self.assertEqual(red.returncode, 1, red.stdout)
        self.assertIn("opencode: share fora do repo", red.stdout)
        self.assertIn("opencode: agents/auditor.md fora do repo", red.stdout)
        self.assertIn("conferir.md não aponta", red.stdout)

        first = self.hook("setup.sh")
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertIn("OpenCode: share (add)", first.stdout)
        self.assertIn("sem ", first.stdout)  # o aviso do modelos.json
        for name in ("conferir", "lacunas"):
            link = self.cfg / "commands" / (name + ".md")
            self.assertTrue(link.is_symlink(), name)
            self.assertEqual(link.resolve(), (PKG / "opencode" / "commands" / (name + ".md")).resolve())

        green = self.hook("check.sh")
        self.assertEqual(green.returncode, 0, green.stdout)
        self.assertIn("opencode.json e arquivos gerados em dia", green.stdout)

        before = {str(p): p.stat().st_mtime_ns for p in self.cfg.rglob("*") if p.is_file()}
        second = self.hook("setup.sh")
        self.assertIn("config e arquivos gerados em dia", second.stdout)
        self.assertEqual({str(p): p.stat().st_mtime_ns for p in self.cfg.rglob("*") if p.is_file()}, before)

    def test_link_pendurado_do_repo_sai_e_arquivo_real_fica(self):
        self.fake_opencode("2.2.7")
        (self.cfg / "commands").mkdir(parents=True)
        (self.cfg / "commands" / "velho.md").symlink_to(PKG / "opencode" / "commands" / "velho.md")
        alheio = self.tmp / "alheio.md"
        (self.cfg / "commands" / "alheio.md").symlink_to(alheio)
        (self.cfg / "commands" / "conferir.md").write_text("meu\n")
        out = self.hook("setup.sh")
        self.assertFalse((self.cfg / "commands" / "velho.md").is_symlink())
        self.assertTrue((self.cfg / "commands" / "alheio.md").is_symlink())
        self.assertEqual((self.cfg / "commands" / "conferir.md").read_text(), "meu\n")
        self.assertIn("conferir.md é arquivo real", out.stdout)

    def test_so_jsonc_o_setup_avisa_e_o_check_fica_vermelho(self):
        self.fake_opencode("2.2.7")
        self.cfg.mkdir()
        (self.cfg / "opencode.jsonc").write_text("{}\n")
        self.hook("setup.sh")
        self.assertFalse((self.cfg / "opencode.json").exists())
        out = self.hook("check.sh")
        self.assertEqual(out.returncode, 1)
        self.assertIn("só há opencode.jsonc", out.stdout)

    def test_opencode_json_ilegivel_e_aviso_no_setup_e_no_check_sem_gravar(self):
        self.fake_opencode("2.2.7")
        self.cfg.mkdir()
        (self.cfg / "opencode.json").write_text("{ nao")
        out = self.hook("setup.sh")
        self.assertIn("nada aplicado", out.stdout)
        self.assertEqual((self.cfg / "opencode.json").read_text(), "{ nao")
        self.assertIn("não deu para comparar", self.hook("check.sh").stdout)


class Plugins(Base):
    """Os plugins locais do TUI (opencode/plugins/<nome>/): um symlink por diretório.

    Roda sobre uma cópia do pacote com um plugin de teste, para não depender de quais
    plugins o repo tem hoje."""

    def setUp(self):
        super().setUp()
        self.repo = self.tmp / "dot"
        (self.repo / "agents").parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(PKG, self.repo / "agents", symlinks=True, ignore=shutil.ignore_patterns("__pycache__", "mods", "tests"))
        shutil.copytree(PKG.parent / "lib", self.repo / "lib")
        for old in (self.repo / "agents" / "opencode" / "plugins",):
            shutil.rmtree(old, ignore_errors=True)
        self.src = self.repo / "agents" / "opencode" / "plugins" / "teste"
        self.src.mkdir(parents=True)
        (self.src / "tui.tsx").write_text("export default {}\n")
        self.fake_opencode("2.2.7")

    def hook(self, name, **kw):
        return subprocess.run(
            ["bash", str(self.repo / "agents" / "hooks" / name)], capture_output=True, text=True, env=self.env(**kw)
        )

    def test_o_setup_linka_o_diretorio_e_o_check_fecha(self):
        red = self.hook("check.sh")
        self.assertEqual(red.returncode, 1, red.stdout)
        self.assertIn("plugins/teste não aponta", red.stdout)
        out = self.hook("setup.sh")
        self.assertEqual(out.returncode, 0, out.stderr)
        link = self.cfg / "plugins" / "teste"
        self.assertTrue(link.is_symlink())
        self.assertEqual(link.resolve(), self.src.resolve())
        self.assertTrue((link / "tui.tsx").is_file())
        green = self.hook("check.sh")
        self.assertEqual(green.returncode, 0, green.stdout)
        self.assertIn("plugins/teste ->", green.stdout)
        self.assertEqual(link.readlink(), self.src)  # a segunda aplicação não refaz o link
        self.assertIn("config e arquivos gerados em dia", self.hook("setup.sh").stdout)

    def test_plugin_que_saiu_do_repo_sai_do_diretorio_de_config(self):
        self.hook("setup.sh")
        link = self.cfg / "plugins" / "teste"
        self.assertTrue(link.is_symlink())
        shutil.rmtree(self.src)
        out = self.hook("setup.sh")
        self.assertFalse(link.is_symlink())
        self.assertIn("Link pendurado removido", out.stdout)

    def test_o_que_nao_e_do_repo_fica_onde_esta(self):
        (self.cfg / "plugins").mkdir(parents=True)
        alheio = self.tmp / "alheio"
        alheio.mkdir()
        (self.cfg / "plugins" / "alheio").symlink_to(alheio)
        (self.cfg / "plugins" / "morto").symlink_to(self.tmp / "nao-existe")
        (self.cfg / "plugins" / "teste").mkdir()  # diretório real no lugar do link
        out = self.hook("setup.sh")
        self.assertTrue((self.cfg / "plugins" / "alheio").is_symlink())
        self.assertTrue((self.cfg / "plugins" / "morto").is_symlink())
        self.assertFalse((self.cfg / "plugins" / "teste").is_symlink())
        self.assertIn("plugins/teste é arquivo real", out.stdout)
        check = self.hook("check.sh")
        self.assertEqual(check.returncode, 0, check.stdout)
        self.assertIn("plugins/teste é arquivo real", check.stdout)


if __name__ == "__main__":
    unittest.main()
