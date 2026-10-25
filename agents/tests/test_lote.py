"""Testes do `agents/skills/implementar/scripts/lote`: quem entra no lote, o
checklist, as tasks citadas com a fase de hoje, e o que o repo já tem do id.

`select`, `checklist`, `cited` e `of_task` são puras. O repo precisa de git de
verdade: cada teste monta um clone num diretório temporário. O `freitask` e o
`vault-vinculos` da ponta a ponta são falsos no PATH."""

import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.dont_write_bytecode = True  # o script testado não ganha __pycache__ ao lado
SCRIPT = Path(__file__).resolve().parents[1] / "skills" / "implementar" / "scripts" / "lote"
GIT_ENV = {
    "GIT_CONFIG_GLOBAL": os.devnull,
    "GIT_CONFIG_NOSYSTEM": "1",
    "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
    "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t",
}


def load():
    loader = importlib.machinery.SourceFileLoader("lote", str(SCRIPT))
    spec = importlib.util.spec_from_loader("lote", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


L = load()


def git(cwd, *args):
    return subprocess.run(["git", "-C", str(cwd), *args], check=True, capture_output=True, text=True).stdout.strip()


def task(id_, callout="tip", status="Refinada", **kw):
    return {"id": id_, "project": "p", "callout": callout, "status": status, "path": "/v/%s.md" % id_,
            "desc": "", "prioridade": None, "hidden": False, "archived": None, **kw}


class Select(unittest.TestCase):
    ACTIVE = [
        task("alta", "example", "Em implementação", prioridade="alta"),
        task("crua", "todo", "Não iniciada"),
        task("refinada"),
        task("em-homologacao", "question", "Em homologação"),
        task("algum-dia", "quote", "Algum dia", hidden=True),
    ]

    def test_sem_id_so_refinada_e_em_implementacao_na_ordem_do_freitask(self):
        tasks, missing = L.select(self.ACTIVE, [])
        self.assertEqual([t["id"] for t in tasks], ["alta", "refinada"])
        self.assertEqual(missing, [])

    def test_com_id_vale_qualquer_fase_e_a_ordem_pedida(self):
        tasks, _ = L.select(self.ACTIVE, ["em-homologacao", "crua"])
        self.assertEqual([t["id"] for t in tasks], ["em-homologacao", "crua"])

    def test_id_repetido_entra_uma_vez_e_o_que_falta_sai_a_parte(self):
        tasks, missing = L.select(self.ACTIVE, ["refinada", "sumiu", "refinada"])
        self.assertEqual([t["id"] for t in tasks], ["refinada"])
        self.assertEqual(missing, ["sumiu"])


class Checklist(unittest.TestCase):
    def test_conta_marcados_e_abertos(self):
        text = "- [x] um\n  - [ ] dois\n- [X] três\n- [ ] quatro\n"
        self.assertEqual(L.checklist(text), "2 de 4 marcados")

    def test_sem_item(self):
        self.assertEqual(L.checklist("texto [ ] solto"), "sem checklist")


class Cited(unittest.TestCase):
    ACTIVE = [task("eu"), task("outra", "example", "Em implementação")]
    ARCHIVED = [task("velha", "done", "Arquivada", archived="done")]

    def test_fase_de_hoje_da_ativa_e_da_arquivada(self):
        text = ("[[projects/p/tasks/outra|outra]] e "
                "[[projects/p/tasks/archived/done/velha|velha]] e [[projects/q/tasks/sumiu]]")
        self.assertEqual(L.cited(text, "eu", self.ACTIVE, self.ARCHIVED),
                         ["`outra` (Em implementação)", "`velha` (arquivada, done)", "`sumiu` (não existe)"])

    def test_link_antigo_para_archived_vale_a_fase_de_hoje(self):
        # O wikilink ainda aponta para archived/, mas a task foi desarquivada.
        text = "[[projects/p/tasks/archived/dropped/outra|outra]]"
        self.assertEqual(L.cited(text, "eu", self.ACTIVE, self.ARCHIVED), ["`outra` (Em implementação)"])

    def test_sem_a_propria_sem_repetir_e_sem_adr(self):
        text = ("[[projects/p/tasks/eu|eu]] [[projects/p/tasks/outra|outra]] "
                "[[projects/p/tasks/outra#Checklist|outra]] [[0005-o-ticket-e-a-task]]")
        self.assertEqual(L.cited(text, "eu", self.ACTIVE, self.ARCHIVED), ["`outra` (Em implementação)"])

    def test_link_curto_so_quando_e_de_task(self):
        text = "[[velha]] [[outra|a outra]] [[mapa-do-workflow]] [[hosts/pi01|pi01]] [[outra]]"
        self.assertEqual(L.cited(text, "eu", self.ACTIVE, self.ARCHIVED),
                         ["`velha` (arquivada, done)", "`outra` (Em implementação)"])


class OfTask(unittest.TestCase):
    def test_a_branch_e_a_sub_branch_de_area(self):
        self.assertTrue(L.of_task("x", "x"))
        self.assertTrue(L.of_task("x-backend", "x"))

    def test_outra_branch_com_o_mesmo_comeco(self):
        self.assertFalse(L.of_task("xy", "x"))
        self.assertFalse(L.of_task(None, "x"))


class RepoLines(unittest.TestCase):
    def setUp(self):
        self.env = mock.patch.dict(os.environ, GIT_ENV)
        self.env.start()
        self.tmp = tempfile.TemporaryDirectory()
        self.main = os.path.realpath(os.path.join(self.tmp.name, "repo"))
        git(self.tmp.name, "init", "-q", "-b", "main", self.main)
        git(self.main, "commit", "-q", "--allow-empty", "-m", "base")

    def tearDown(self):
        self.tmp.cleanup()
        self.env.stop()

    def test_sem_nada_do_id_sem_esteira_so_o_clone(self):
        self.assertEqual(L.repo_lines(self.main, "x", None),
                         ["repo %s (sem esteira de PR): clone principal em `main`, limpo" % L.tilde(self.main)])

    def test_branch_e_worktrees_do_id_com_sujos_e_idade(self):
        git(self.main, "branch", "x")
        wt = os.path.join(self.main, ".claude", "worktrees", "x-backend")
        git(self.main, "worktree", "add", "-q", "-b", "x-backend", wt, "x")
        git(self.main, "worktree", "add", "-q", "-b", "xy", os.path.join(self.tmp.name, "xy"), "main")
        Path(wt, "novo").write_text("a")
        lines = L.repo_lines(self.main, "x", None)
        self.assertIn("  branch `x`: local", lines)
        self.assertEqual([l for l in lines if "worktree" in l],
                         ["  worktree %s [x-backend]: 1 sujo, último commit há 0 min" % L.tilde(wt)])

    def test_worktree_sem_commit_proprio_nao_tem_idade(self):
        # Recém-criada da base: a idade seria a do último commit da base, e a task pareceria em voo.
        git(self.main, "update-ref", "refs/remotes/origin/main", "HEAD")
        git(self.main, "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main")
        nova = os.path.join(self.tmp.name, "nova")
        git(self.main, "worktree", "add", "-q", "-b", "x", nova, "main")
        self.assertEqual([l for l in L.repo_lines(self.main, "x", None) if "worktree" in l],
                         ["  worktree %s [x]: limpa, sem commit próprio (está em `origin/main`)" % L.tilde(nova)])
        git(nova, "commit", "-q", "--allow-empty", "-m", "item 1")
        self.assertIn("último commit há 0 min", [l for l in L.repo_lines(self.main, "x", None) if "worktree" in l][0])

    def test_clone_sujo_aparece(self):
        Path(self.main, "a").write_text("a")
        Path(self.main, "b").write_text("b")
        self.assertIn("2 sujos", L.repo_lines(self.main, "x", None)[0])

    def test_com_esteira_diz_a_pr_e_a_label(self):
        os.makedirs(os.path.join(self.main, ".github", "workflows"))
        prs = [{"number": 7, "state": "OPEN", "labels": [{"name": "ready-for-uat"}]}]
        lines = L.repo_lines(self.main, "x", prs)
        self.assertIn("(esteira de PR)", lines[0])
        self.assertEqual(lines[-1], "  PR #7 OPEN [ready-for-uat]")

    def test_com_esteira_e_sem_rede_diz_que_nao_consultou(self):
        os.makedirs(os.path.join(self.main, ".github", "workflows"))
        self.assertEqual(L.repo_lines(self.main, "x", None)[-1], "  PR: não consultei")


class PontaAPonta(unittest.TestCase):
    """O script inteiro, com `freitask` e `vault-vinculos` falsos no PATH."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        self.bin = base / "bin"
        self.bin.mkdir()
        (base / "a.md").write_text("> [!tip] A\n\n- [x] um\n- [ ] dois\n[[projects/p/tasks/b|b]]\n")
        (base / "b.md").write_text("> [!todo] B\n")
        active = [task("a", path=str(base / "a.md")), task("b", "todo", "Não iniciada", path=str(base / "b.md"))]
        (base / "ativas.json").write_text(json.dumps(active))
        (base / "arquivadas.json").write_text("[]")
        self.fake("freitask", 'case "$*" in *--archived*) cat %s/arquivadas.json;; *) cat %s/ativas.json;; esac'
                  % (base, base))
        self.fake("vault-vinculos", 'case "$1" in hosts) printf "h1\\t1\\th1\\t\\t%s/h1.md\\n";; esac' % base)
        self.env = dict(os.environ, PATH="%s:%s" % (self.bin, os.environ["PATH"]))

    def tearDown(self):
        self.tmp.cleanup()

    def fake(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/bash\n%s\n" % body)
        path.chmod(0o755)

    def lote(self, *args):
        return subprocess.run([sys.executable, "-I", str(SCRIPT), "--sem-rede", *args],
                              capture_output=True, text=True, env=self.env)

    def test_sem_id(self):
        r = self.lote()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("# lote: 1 task", r.stdout)
        self.assertIn("máquina: h1 · nota: ", r.stdout)
        self.assertIn("- checklist: 1 de 2 marcados", r.stdout)
        self.assertIn("- cita: `b` (Não iniciada)", r.stdout)
        self.assertIn("- repo: nenhum vinculado ao projeto", r.stdout)

    def test_com_id_que_falta(self):
        r = self.lote("b", "c")
        self.assertIn("## b\n- projeto p · Não iniciada · normal", r.stdout)
        self.assertIn("## não achei\n- `c`: não está entre as tasks ativas", r.stdout)

    def test_sem_freitask_sai_1_e_diz_por_que(self):
        self.fake("freitask", "exit 1")
        r = self.lote()
        self.assertEqual(r.returncode, 1)
        self.assertIn("freitask list --json", r.stdout)


if __name__ == "__main__":
    unittest.main()
