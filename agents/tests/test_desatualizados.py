"""Testes do `agents/skills/estudar-codebase/scripts/desatualizados.py`: as âncoras
que o texto de um capítulo declara e os três estados que o script dá por capítulo.

`parse_anchors`, `parse_frontmatter` e `codebase_path` são puras. Os estados
precisam de git de verdade: cada teste monta um repo num diretório temporário,
com o estudo ao lado (README.md com a linha `- **Codebase:**` e `mapa/`)."""

import importlib.machinery
import importlib.util
import io
import os
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

sys.dont_write_bytecode = True  # o script testado não ganha __pycache__ ao lado
SCRIPT = Path(__file__).resolve().parents[1] / "skills" / "estudar-codebase" / "scripts" / "desatualizados.py"
GIT_ENV = {
    "GIT_CONFIG_GLOBAL": os.devnull,
    "GIT_CONFIG_NOSYSTEM": "1",
    "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
    "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t",
}


def load():
    loader = importlib.machinery.SourceFileLoader("desatualizados", str(SCRIPT))
    spec = importlib.util.spec_from_loader("desatualizados", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


D = load()

SERVICE = '''\
class Service:
    def run(self, order):
        total = 0
        for item in order:
            total += item.price
        return total

    def other(self):
        return 1
'''


def git(cwd, *args):
    return subprocess.run(["git", "-C", str(cwd), *args], check=True, capture_output=True, text=True).stdout.strip()


class Parsing(unittest.TestCase):
    def test_ancora_com_dica_de_linha_e_metodo(self):
        text = "1. `app/service.py#Service.run` (L2@abc1234) chama `app/repo.py#save`."
        self.assertEqual(D.parse_anchors(text), [("app/service.py", "Service.run"), ("app/repo.py", "save")])

    def test_ancora_repetida_conta_uma_vez(self):
        self.assertEqual(D.parse_anchors("`a.py#f` e `a.py#f`"), [("a.py", "f")])

    def test_o_que_nao_e_ancora(self):
        for text in ("`https://x.dev/doc#secao`", "[a](b.md#c)", "a.py#f fora das crases", "`sem-simbolo.py`",
                     "`a b.py#f`", "`a.py#`"):
            with self.subTest(text=text):
                self.assertEqual(D.parse_anchors(text), [])

    def test_parenteses_do_simbolo_saem(self):
        self.assertEqual(D.parse_anchors("`a.py#Service.run()`"), [("a.py", "Service.run")])

    def test_frontmatter(self):
        fm = D.parse_frontmatter('---\ntitle: "Check-in"\nsha: a1b2c3d\nmapeado: 2026-11-07\n---\ncorpo: x\n')
        self.assertEqual(fm, {"title": "Check-in", "sha": "a1b2c3d", "mapeado": "2026-11-07"})

    def test_sem_frontmatter(self):
        self.assertEqual(D.parse_frontmatter("# só corpo\nsha: abc1234\n"), {})

    def test_linha_codebase_do_adaptador(self):
        home = os.path.expanduser("~")
        self.assertEqual(D.codebase_path("# x\n\n- **Codebase:** ~/dev/repo\n"), home + "/dev/repo")
        self.assertEqual(D.codebase_path("- **Codebase:** `/srv/repo`  \n"), "/srv/repo")
        self.assertIsNone(D.codebase_path("# x\n- **Fonte:** `mapa/`\n"))


class Estudo(unittest.TestCase):
    """Um repo com `app/service.py` e um estudo com um capítulo por teste."""

    def setUp(self):
        patcher = mock.patch.dict(os.environ, GIT_ENV)
        patcher.start()
        self.addCleanup(patcher.stop)
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(os.path.realpath(tmp.name))
        self.repo = self.tmp / "repo"
        self.study = self.tmp / "study" / "repo"
        (self.study / "mapa").mkdir(parents=True)
        subprocess.run(["git", "init", "-q", "-b", "main", str(self.repo)], check=True)
        self.commit({"app/service.py": SERVICE}, "inicial")
        self.first = self.head()
        (self.study / "README.md").write_text(f"# estudo\n\n- **Codebase:** {self.repo}\n")

    def commit(self, files, subject):
        for rel, text in files.items():
            target = self.repo / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text)
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-q", "-m", subject)

    def head(self):
        return git(self.repo, "rev-parse", "--short=7", "HEAD")

    def chapter(self, name="01-pedido.md", sha=None, anchors=("app/service.py#Service.run",), title="Pedido"):
        sha = self.first if sha is None else sha
        body = "".join(f"{i}. `{a}` (L1@{sha})\n" for i, a in enumerate(anchors, 1))
        front = f"---\ntitle: {title}\nsha: {sha}\nmapeado: 2026-11-07\n---\n" if sha else "---\ntitle: x\n---\n"
        (self.study / "mapa" / name).write_text(front + f"\n# {title}\n\n## O fluxo\n\n{body}")

    def states(self):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = D.main([str(self.study)])
        self.assertEqual(code, 0, err.getvalue())
        lines = out.getvalue().splitlines()
        return {line.split(" (")[0]: line.split(" — ", 1)[1] for line in lines[1:] if " — " in line}

    def test_sha_no_head_esta_em_dia(self):
        self.chapter(sha=self.head())
        self.assertEqual(self.states(), {"01-pedido.md": "em dia"})

    def test_commit_que_nao_toca_o_arquivo_deixa_em_dia(self):
        self.commit({"outro.py": "x = 1\n"}, "outro arquivo")
        self.chapter()
        self.assertEqual(self.states(), {"01-pedido.md": "em dia"})

    def test_mudanca_dentro_do_metodo_toca_so_a_ancora_dele(self):
        # A linha mudada não cita `run`: quem acha o método é o cabeçalho do hunk.
        self.commit({"app/service.py": SERVICE.replace("total += item.price", "total += item.price * 2")}, "dobra")
        self.chapter(anchors=("app/service.py#Service.run", "app/service.py#Service.other"))
        self.assertEqual(self.states(), {"01-pedido.md": "tocado: app/service.py#Service.run"})

    def test_linha_mudada_que_cita_o_simbolo_toca_mesmo_com_outro_cabecalho(self):
        # O hunk está em `other` (é o cabeçalho dele), mas a linha mudada chama `run`.
        self.commit({"app/service.py": SERVICE.replace("return 1", "return self.run(None)")}, "other chama run")
        self.chapter(anchors=("app/service.py#Service.run",))
        self.assertEqual(self.states(), {"01-pedido.md": "tocado: app/service.py#Service.run"})

    def test_cabecalho_que_cita_o_simbolo_toca_mesmo_sem_a_linha_citar(self):
        self.commit({"app/service.py": SERVICE.replace("return 1", "return 2")}, "other")
        self.chapter(anchors=("app/service.py#Service.other",))
        self.assertEqual(self.states(), {"01-pedido.md": "tocado: app/service.py#Service.other"})

    def test_sha_antigo_so_conta_o_que_veio_depois(self):
        self.commit({"app/service.py": SERVICE.replace("return 1", "return 2")}, "other")
        self.chapter(sha=self.head(), anchors=("app/service.py#Service.other",))
        self.assertEqual(self.states(), {"01-pedido.md": "em dia"})

    def test_simbolo_que_sumiu_e_quebrada(self):
        self.chapter(anchors=("app/service.py#Service.gone",))
        state = self.states()["01-pedido.md"]
        self.assertTrue(state.startswith("quebrada: app/service.py#Service.gone"), state)
        self.assertIn("`gone`", state)

    def test_classe_e_metodo_precisam_existir_os_dois(self):
        self.chapter(anchors=("app/service.py#Missing.run",))
        self.assertTrue(self.states()["01-pedido.md"].startswith("quebrada: app/service.py#Missing.run"))

    def test_arquivo_apagado_e_quebrada(self):
        self.commit({"app/other.py": "def f(): pass\n"}, "outro")
        git(self.repo, "rm", "-q", "app/other.py")
        git(self.repo, "commit", "-q", "-m", "apaga")
        self.chapter(anchors=("app/other.py#f",))
        self.assertIn("arquivo não existe no HEAD", self.states()["01-pedido.md"])

    def test_quebrada_vence_tocada(self):
        self.commit({"app/service.py": SERVICE.replace("return 1", "return 2")}, "other")
        self.chapter(anchors=("app/service.py#Service.other", "app/service.py#Service.gone"))
        state = self.states()["01-pedido.md"]
        self.assertTrue(state.startswith("quebrada:"), state)
        self.assertNotIn("tocado", state)

    def test_capitulo_que_nao_se_pode_conferir_sai_quebrada_com_o_motivo(self):
        self.chapter("01-sem-sha.md", sha="")
        self.chapter("02-sha-fantasma.md", sha="deadbee")
        (self.study / "mapa" / "03-sem-ancora.md").write_text(f"---\nsha: {self.first}\n---\n\n# x\n")
        states = self.states()
        self.assertIn("sem `sha:`", states["01-sem-sha.md"])
        self.assertIn("não existe neste repo", states["02-sha-fantasma.md"])
        self.assertIn("sem âncora", states["03-sem-ancora.md"])
        self.assertTrue(all(s.startswith("quebrada:") for s in states.values()))

    def test_um_estado_por_capitulo_e_o_index_fica_de_fora(self):
        self.commit({"app/service.py": SERVICE.replace("return 1", "return 2")}, "other")
        self.chapter("01-a.md", anchors=("app/service.py#Service.other",))
        self.chapter("02-b.md", sha=self.head(), anchors=("app/service.py#Service.run",))
        (self.study / "mapa" / "00-index.md").write_text("# Mapa\n\n- `app/service.py#Service.run`\n")
        states = self.states()
        self.assertEqual(list(states), ["01-a.md", "02-b.md"])
        self.assertTrue(states["01-a.md"].startswith("tocado:"))
        self.assertEqual(states["02-b.md"], "em dia")

    def test_gitattributes_do_repo_vale_mais_que_os_drivers_do_script(self):
        # `plain` não define padrão de função: o cabeçalho do hunk volta a ser `class Service:`, que não cita `run`.
        self.commit({".gitattributes": "*.py diff=plain\n"}, "driver do repo")
        base = self.head()
        self.commit({"app/service.py": SERVICE.replace("total += item.price", "total += item.price * 2")}, "dobra")
        self.chapter(sha=base)
        self.assertEqual(self.states(), {"01-pedido.md": "em dia"})

    def test_mapa_vazio(self):
        out = io.StringIO()
        with redirect_stdout(out):
            self.assertEqual(D.main([str(self.study)]), 0)
        self.assertIn("nenhum capítulo em mapa/", out.getvalue())


class Erros(unittest.TestCase):
    def run_main(self, folder):
        err = io.StringIO()
        with redirect_stderr(err), redirect_stdout(io.StringIO()):
            return D.main([str(folder)]), err.getvalue()

    def test_sem_readme(self):
        with tempfile.TemporaryDirectory() as tmp:
            code, err = self.run_main(tmp)
        self.assertEqual(code, 2)
        self.assertIn("README.md", err)

    def test_readme_sem_a_linha_codebase(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "README.md").write_text("# x\n\n## Regras de estudo\n\n- **Fonte:** `mapa/`\n")
            code, err = self.run_main(tmp)
        self.assertEqual(code, 2)
        self.assertIn("Codebase", err)

    def test_codebase_que_nao_e_repo(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "README.md").write_text(f"- **Codebase:** {tmp}/nada\n")
            code, err = self.run_main(tmp)
        self.assertEqual(code, 2)
        self.assertIn("não é um repo git", err)


if __name__ == "__main__":
    unittest.main()
