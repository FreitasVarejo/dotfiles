"""Testes do `vault/.local/bin/vault-arquivaveis` num vault de fixture.

Os repos de cada projeto e as PRs vêm de dublês; a saída JSON é conferida pelo
`main` de verdade, num subprocesso, nos casos que não precisam de rede."""

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

sys.dont_write_bytecode = True  # o executável testado não ganha __pycache__ ao lado
SCRIPT = Path(__file__).resolve().parents[1] / ".local" / "bin" / "vault-arquivaveis"


def load():
    loader = importlib.machinery.SourceFileLoader("vault_arquivaveis", str(SCRIPT))
    spec = importlib.util.spec_from_loader("vault_arquivaveis", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


A = load()


def um_repo(*args, cols=1):
    return [["/r/" + args[1], "/r/" + args[1], args[1]]] if args[0] == "repos" else [["x"]]


class Arquivaveis(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.vault = Path(os.path.realpath(tmp.name))
        self.prs = {}
        for target, fake in (("VAULT", str(self.vault)),
                             ("vinculos", um_repo),
                             ("slug", lambda root: "o/" + os.path.basename(root)),
                             ("pr_states", lambda s, branch: self.prs.get((s, branch), []))):
            patcher = mock.patch.object(A, target, fake)
            patcher.start()
            self.addCleanup(patcher.stop)

    def task(self, project, tid, callout="question", aberto=False):
        path = self.vault / "projects" / project / "tasks" / (tid + ".md")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("> [!%s] %s\n> [[projects/%s/tasks/%s|%s]]\n\n- [x] feito\n%s"
                        % (callout, tid, project, tid, tid, "- [ ] falta\n" if aberto else ""))

    def arquivaveis(self, projects=("p",), net=True):
        return A.arquivaveis(list(projects), net)

    def pode(self, p, t, fase, callout, prs):
        return {"projeto": p, "id": t, "fase": fase, "callout": callout, "estado": "pode-arquivar",
                "prs": [{"repo": r, "numero": n} for r, n in prs]}

    def test_pr_mergeada_sem_item_aberto_entra(self):
        self.task("p", "pronta")
        self.prs[("o/p", "pronta")] = [(7, "MERGED")]
        self.assertEqual(self.arquivaveis(), {"consultou": True, "motivo": "", "tasks": [
            self.pode("p", "pronta", "Em homologação", "question", [("o/p", 7)])]})

    def test_bloqueada_com_pr_mergeada_entra_com_a_fase(self):
        self.task("p", "parou", callout="warning")
        self.prs[("o/p", "parou")] = [(7, "MERGED")]
        self.assertEqual(self.arquivaveis()["tasks"], [self.pode("p", "parou", "Bloqueada", "warning", [("o/p", 7)])])

    def test_bloqueada_com_pr_aberta_ou_item_aberto_fica(self):
        self.task("p", "pr-aberta", callout="warning")
        self.task("p", "com-item", callout="warning", aberto=True)
        self.prs[("o/p", "pr-aberta")] = [(7, "MERGED"), (9, "OPEN")]
        self.prs[("o/p", "com-item")] = [(8, "MERGED")]
        self.assertEqual(self.arquivaveis()["tasks"], [])

    def test_item_aberto_fica(self):
        self.task("p", "falta", aberto=True)
        self.prs[("o/p", "falta")] = [(7, "MERGED")]
        self.assertEqual(self.arquivaveis()["tasks"], [])

    def test_pr_aberta_da_mesma_branch_fica(self):
        self.task("p", "outra-pr")
        self.prs[("o/p", "outra-pr")] = [(7, "MERGED"), (9, "OPEN")]
        self.assertEqual(self.arquivaveis()["tasks"], [])

    def test_pr_aberta_noutro_repo_do_projeto_fica(self):
        self.task("p", "dois-repos")
        self.prs[("o/a", "dois-repos")] = [(7, "MERGED")]
        self.prs[("o/b", "dois-repos")] = [(3, "OPEN")]
        dois = lambda *a, cols=1: [["/r/a", "/r/a", "p"], ["/r/b", "/r/b", "p"]] if a[0] == "repos" else [["x"]]
        with mock.patch.object(A, "vinculos", dois):
            self.assertEqual(self.arquivaveis()["tasks"], [])
            del self.prs[("o/b", "dois-repos")]
            self.assertEqual(self.arquivaveis()["tasks"],
                             [self.pode("p", "dois-repos", "Em homologação", "question", [("o/a", 7)])])

    def test_so_pr_fechada_ou_nenhuma_fica(self):
        self.task("p", "fechada")
        self.task("p", "sem-pr")
        self.prs[("o/p", "fechada")] = [(7, "CLOSED")]
        self.assertEqual(self.arquivaveis()["tasks"], [])

    def test_fora_de_homologacao_ou_de_projeto_nao_pedido_fica(self):
        self.task("p", "em-implementacao", callout="example")
        self.task("q", "de-outro-projeto")
        self.prs[("o/p", "em-implementacao")] = [(7, "MERGED")]
        self.prs[("o/q", "de-outro-projeto")] = [(8, "MERGED")]
        self.assertEqual(self.arquivaveis()["tasks"], [])

    def test_task_arquivada_nao_entra(self):
        path = self.vault / "projects" / "p" / "tasks" / "archived" / "done" / "velha.md"
        path.parent.mkdir(parents=True)
        path.write_text("> [!question] velha\n")
        self.prs[("o/p", "velha")] = [(7, "MERGED")]
        self.assertEqual(self.arquivaveis()["tasks"], [])

    def test_lista_de_projetos_ordena_por_projeto_e_id(self):
        for p, t in (("q", "a"), ("p", "z"), ("p", "b")):
            self.task(p, t)
            self.prs[("o/" + p, t)] = [(1, "MERGED")]
        ids = [(t["projeto"], t["id"]) for t in self.arquivaveis(("q", "p"))["tasks"]]
        self.assertEqual(ids, [("p", "b"), ("p", "z"), ("q", "a")])

    def test_gh_que_falha_marca_a_task_com_os_repos(self):
        self.task("p", "pronta")
        with mock.patch.object(A, "pr_states", return_value=None):
            doc = self.arquivaveis()
        self.assertEqual(doc["tasks"], [{"projeto": "p", "id": "pronta", "fase": "Em homologação",
                                         "callout": "question", "estado": "gh-falhou", "repos": ["o/p"]}])

    def test_vinculos_que_falta_diz_que_nao_consultou(self):
        self.task("p", "pronta")
        with mock.patch.object(A, "vinculos", return_value=None):
            doc = self.arquivaveis()
        self.assertFalse(doc["consultou"])
        self.assertIn("vault-vinculos", doc["motivo"])
        self.assertEqual(doc["tasks"], [])

    def test_sem_rede_nao_consulta(self):
        self.task("p", "pronta")
        self.prs[("o/p", "pronta")] = [(7, "MERGED")]
        self.assertEqual(self.arquivaveis(net=False), {"consultou": False, "motivo": "--sem-rede", "tasks": []})


class Linha(unittest.TestCase):
    """O executável de verdade, num HOME de fixture, sem rede."""

    def roda(self, *args):
        with tempfile.TemporaryDirectory() as home:
            env = {**os.environ, "HOME": home}
            return subprocess.run([sys.executable, "-I", str(SCRIPT), *args], capture_output=True, text=True, env=env)

    def test_sem_rede_sai_json_e_0(self):
        r = self.roda("--sem-rede", "p")
        self.assertEqual(r.returncode, 0)
        self.assertEqual(json.loads(r.stdout), {"consultou": False, "motivo": "--sem-rede", "tasks": []})

    def test_help_diz_a_regra(self):
        r = self.roda("--help")
        self.assertEqual(r.returncode, 0)
        self.assertIn("nenhuma aberta", r.stdout)

    def test_opcao_desconhecida_sai_2(self):
        self.assertEqual(self.roda("--nao-existe").returncode, 2)

    def test_vault_sem_tasks_responde_vazio_sem_chamar_nada(self):
        r = self.roda("p")
        self.assertEqual(r.returncode, 0)
        self.assertEqual(json.loads(r.stdout), {"consultou": True, "motivo": "", "tasks": []})


if __name__ == "__main__":
    unittest.main()
