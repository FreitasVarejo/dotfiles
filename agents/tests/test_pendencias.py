"""Testes do `agents/skills/fechar/scripts/pendencias --plano`: o item de push, o
pull e o setup do outro host que dependem dele, e quando o diff pede `./setup.sh`.

`decide_host`, `setup_reason` e `render_plan` são puras. O push e o diff local
precisam de git de verdade: cada teste monta um bare como `origin` num diretório
temporário."""

import importlib.machinery
import importlib.util
import os
import shlex
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.dont_write_bytecode = True  # o script testado não ganha __pycache__ ao lado
SCRIPT = Path(__file__).resolve().parents[1] / "skills" / "fechar" / "scripts" / "pendencias"
GIT_ENV = {
    "GIT_CONFIG_GLOBAL": os.devnull,
    "GIT_CONFIG_NOSYSTEM": "1",
    "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
    "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t",
}


def load():
    loader = importlib.machinery.SourceFileLoader("pendencias", str(SCRIPT))
    spec = importlib.util.spec_from_loader("pendencias", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


P = load()


def git(cwd, *args):
    return subprocess.run(["git", "-C", str(cwd), *args], check=True, capture_output=True, text=True).stdout.strip()


class SetupReason(unittest.TestCase):
    PEDEM = [
        ("M", "agents/permissions/deny.json"),
        ("M", "agents/settings/claude.json"),
        ("M", "agents/travas/travas.json"),
        ("M", "agents/mcp/playwright.json"),
        ("M", "agents/hooks/setup.sh"),
        ("M", "setup.sh"),
        ("M", "vault/hooks/check.sh"),
        ("A", "nvim/init.lua"),
        ("A", "agents/skills/nova/SKILL.md"),
        ("D", "agents/travas/doctor-no-stop"),
        ("D", "bash/.bashrc"),
    ]
    NAO_PEDEM = [
        ("M", "agents/travas/doctor-no-stop"),
        ("M", "agents/travas/verificacao-no-stop"),
        ("M", "agents/skills/fechar/SKILL.md"),
        ("M", "agents/skills/fechar/scripts/pendencias"),
        ("M", "agents/instructions/user.md"),
        ("M", "agents/instructions/machines/pi01.md"),
        ("M", "agents/mcp/README.md"),
        ("M", "agents/tests/test_x.py"),
        ("M", "nvim/init.lua"),
        ("M", "docs/agents/verificacao.md"),
    ]

    def test_pedem(self):
        for st, path in self.PEDEM:
            with self.subTest(st=st, path=path):
                self.assertTrue(P.setup_reason([(st, path)]))

    def test_nao_pedem(self):
        for st, path in self.NAO_PEDEM:
            with self.subTest(st=st, path=path):
                self.assertEqual(P.setup_reason([(st, path)]), "")

    def test_o_motivo_diz_o_arquivo_e_por_que(self):
        reason = P.setup_reason([("M", "agents/permissions/deny.json")])
        self.assertIn("agents/permissions/deny.json", reason)
        self.assertIn("mescla", reason)

    def test_um_arquivo_que_pede_basta(self):
        changes = [("M", "agents/skills/fechar/SKILL.md"), ("M", "agents/settings/claude.json")]
        self.assertIn("agents/settings/claude.json", P.setup_reason(changes))


class DecideHost(unittest.TestCase):
    def fact(self, **kw):
        return {"alvo": "pi01", "behind": 0, "ahead": 0, "dirty": 0, **kw}

    def push(self, ahead=2):
        return P.item("git -C /x push origin main", "push", push={"ahead": ahead})

    def diff(self, changes=(("M", "agents/permissions/deny.json"),)):
        return lambda: (list(changes), None)

    def test_host_em_dia_sem_push_nao_propoe_nada(self):
        self.assertEqual(P.decide_host("pi01", self.fact(), self.diff()), ([], []))

    def test_host_em_dia_com_push_propoe_pull_e_setup_dependentes(self):
        push = self.push(ahead=2)
        items, fora = P.decide_host("pi01", self.fact(), self.diff(), push=push)
        self.assertEqual(fora, [])
        pull, setup = items
        self.assertEqual(pull["cmd"], "ssh pi01 'git -C ~/dotfiles pull --ff-only'")
        self.assertIs(pull["dep"], push)
        self.assertIn("2 commits", pull["why"])
        self.assertIs(setup["dep"], pull)
        self.assertIn("agents/permissions/deny.json", setup["why"])

    def test_com_push_e_sem_motivo_de_setup_so_o_pull(self):
        items, fora = P.decide_host("pi01", self.fact(), self.diff([("M", "nvim/init.lua")]), push=self.push())
        self.assertEqual([i["cmd"] for i in items], ["ssh pi01 'git -C ~/dotfiles pull --ff-only'"])
        self.assertEqual(fora, [])

    def test_host_ja_atras_soma_o_que_o_push_leva(self):
        items, _ = P.decide_host("pi01", self.fact(behind=1), self.diff(), push=self.push(ahead=2))
        self.assertIn("3 commits", items[0]["why"])

    def test_host_ja_atras_sem_push_propoe_o_pull_sem_dependencia(self):
        items, _ = P.decide_host("pi01", self.fact(behind=1), self.diff([("M", "nvim/init.lua")]))
        self.assertIsNone(items[0]["dep"])

    def test_com_push_sem_saber_o_diff_o_host_sai_do_plano(self):
        items, fora = P.decide_host("pi01", self.fact(), lambda: (None, "o commit abc do host não existe no clone local"),
                                    push=self.push())
        self.assertEqual(items, [])
        self.assertEqual(len(fora), 1)
        self.assertIn("não existe no clone local", fora[0])

    def test_host_sujo_ou_a_frente_fica_fora_mesmo_com_push(self):
        for kw in ({"dirty": 2}, {"ahead": 1}):
            with self.subTest(kw=kw):
                items, fora = P.decide_host("pi01", self.fact(**kw), self.diff(), push=self.push())
                self.assertEqual(items, [])
                self.assertEqual(len(fora), 1)


class RenderPlan(unittest.TestCase):
    def test_o_pull_diz_de_qual_push_depende(self):
        push = P.item("git -C /x push origin main", "push")
        pull = P.item("ssh pi01 'git -C ~/dotfiles pull --ff-only'", "depende do push (\0): host atrás", dep=push)
        setup = P.item("ssh pi01 'cd ~/dotfiles && ./setup.sh'", "depende do pull (\0): x", dep=pull)
        lines = P.render_plan([push, pull, setup], [])
        self.assertTrue(lines[0].startswith("P1. git -C /x push origin main"))
        self.assertIn("depende do push (P1)", lines[1])
        self.assertIn("depende do pull (P2)", lines[2])


class Repo(unittest.TestCase):
    """Um clone com bare como origin; a branch padrão é `main`."""

    def setUp(self):
        patcher = mock.patch.dict(os.environ, GIT_ENV)
        patcher.start()
        self.addCleanup(patcher.stop)
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(os.path.realpath(tmp.name))
        self.origin = self.tmp / "origin.git"
        self.work = self.tmp / "work"
        subprocess.run(["git", "init", "-q", "--bare", "-b", "main", str(self.origin)], check=True)
        subprocess.run(["git", "clone", "-q", str(self.origin), str(self.work)], check=True, capture_output=True)
        self.commit(self.work, "inicial")
        git(self.work, "push", "-q", "-u", "origin", "main")
        git(self.work, "remote", "set-head", "origin", "main")

    def commit(self, root, subject, path=None):
        path = path or subject.replace(" ", "-") + ".txt"
        target = Path(root) / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(subject + "\n")
        git(root, "add", "-A")
        git(root, "commit", "-q", "-m", subject)

    def worktree(self, branch, start=None):
        path = self.tmp / branch
        git(self.work, "worktree", "add", "-q", "-b", branch, str(path), *([start] if start else []))
        return path

    def plan(self, *roots, net=True):
        return P.plan_repo(str(self.work), [str(r) for r in roots], net)

    def push_cmd(self, root, branch):
        return "git -C %s push origin %s" % (P.shpath(str(root)), shlex.quote(branch))

    def pushes(self, items):
        return [i for i in items if i.get("push")]


class PlanPush(Repo):
    def test_repo_a_frente_e_sem_esteira_entra(self):
        self.commit(self.work, "feito na sessao")
        items, fora = self.plan(self.work)
        (push,) = self.pushes(items)
        self.assertEqual(push["cmd"], self.push_cmd(self.work, "main"))
        self.assertIn("1 commit", push["why"])
        self.assertIn("feito na sessao", push["why"])
        self.assertEqual(fora, [])

    def test_o_motivo_lista_cada_commit_e_avisa_do_de_outra_sessao(self):
        self.commit(self.work, "primeiro")
        self.commit(self.work, "segundo")
        (push,) = self.pushes(self.plan(self.work)[0])
        self.assertIn("2 commits", push["why"])
        self.assertIn("primeiro", push["why"])
        self.assertIn("segundo", push["why"])
        self.assertIn("outra sessão", push["why"])

    def test_nunca_forca(self):
        self.commit(self.work, "x")
        items, fora = self.plan(self.work)
        for text in [i["cmd"] + i["why"] for i in items] + fora:
            self.assertNotIn("--force", text)
            self.assertNotIn("+main", text)

    def test_em_dia_nao_propoe_nada(self):
        self.assertEqual(self.plan(self.work), ([], []))

    def test_branch_padrao_com_esteira_fica_fora_do_plano(self):
        self.commit(self.work, "ci", ".github/workflows/ci.yml")
        git(self.work, "push", "-q")
        self.commit(self.work, "mais um")
        items, fora = self.plan(self.work)
        self.assertEqual(self.pushes(items), [])
        (motivo,) = fora
        self.assertIn(".github/workflows", motivo)
        self.assertIn("PR", motivo)

    def test_branch_de_pr_a_frente_em_repo_com_esteira_entra(self):
        self.commit(self.work, "ci", ".github/workflows/ci.yml")
        git(self.work, "push", "-q")
        wt = self.worktree("feat")
        self.commit(wt, "da feature")
        git(wt, "push", "-q", "-u", "origin", "feat")
        self.commit(wt, "ajuste do review")
        items, fora = self.plan(wt)
        (push,) = self.pushes(items)
        self.assertEqual(push["cmd"], self.push_cmd(wt, "feat"))
        self.assertIn("ajuste do review", push["why"])
        self.assertEqual(fora, [])

    def test_branch_sem_upstream_e_com_commit_proprio_fica_fora(self):
        wt = self.worktree("nova")
        self.commit(wt, "so local")
        items, fora = self.plan(wt)
        self.assertEqual(self.pushes(items), [])
        (motivo,) = fora
        self.assertIn("sem upstream", motivo)

    def test_branch_recem_criada_sem_commit_nao_aparece(self):
        wt = self.worktree("vazia")
        self.assertEqual(self.pushes(self.plan(wt)[0]), [])
        self.assertEqual([f for f in self.plan(wt)[1] if "sem upstream" in f], [])

    def test_branch_atras_e_a_frente_fica_fora(self):
        outro = self.tmp / "outro"
        subprocess.run(["git", "clone", "-q", str(self.origin), str(outro)], check=True, capture_output=True)
        self.commit(outro, "de outra maquina")
        git(outro, "push", "-q")
        self.commit(self.work, "meu")
        git(self.work, "fetch", "-q")
        items, fora = self.plan(self.work)
        self.assertEqual(self.pushes(items), [])
        (motivo,) = fora
        self.assertIn("atrás", motivo)
        self.assertIn("à frente", motivo)

    def test_branch_so_atras_nao_vira_push(self):
        outro = self.tmp / "outro"
        subprocess.run(["git", "clone", "-q", str(self.origin), str(outro)], check=True, capture_output=True)
        self.commit(outro, "de outra maquina")
        git(outro, "push", "-q")
        git(self.work, "fetch", "-q")
        self.assertEqual(self.plan(self.work), ([], []))

    def test_upstream_com_outro_nome_nunca_vira_push(self):
        # `worktree add -b x origin/main` faz a branch seguir origin/main: `push origin x:main` seria o desastre.
        wt = self.worktree("feat", start="origin/main")
        self.assertEqual(git(wt, "config", "branch.feat.merge"), "refs/heads/main")
        self.commit(wt, "da feature")
        items, fora = self.plan(wt)
        self.assertEqual(self.pushes(items), [])
        (motivo,) = fora
        self.assertIn("origin/main", motivo)
        self.assertIn("nome", motivo)

    def test_sem_rede_nao_propoe_o_push(self):
        self.commit(self.work, "x")
        items, fora = self.plan(self.work, net=False)
        self.assertEqual(self.pushes(items), [])
        (motivo,) = fora
        self.assertIn("--sem-rede", motivo)

    def test_repo_sem_origin_nao_aparece(self):
        sem = self.tmp / "sem"
        subprocess.run(["git", "init", "-q", "-b", "main", str(sem)], check=True)
        self.commit(sem, "so local")
        self.assertEqual(P.plan_repo(str(sem), [str(sem)], True), ([], []))

    def test_cabeca_destacada_nao_aparece(self):
        git(self.work, "checkout", "-q", "--detach")
        self.assertEqual(self.plan(self.work), ([], []))


class PlanHosts(Repo):
    """O host que fica atrás depois do push: o diff é `HEAD do host..HEAD local`."""

    def setUp(self):
        super().setUp()
        self.pre = git(self.work, "rev-parse", "HEAD")
        self.commit(self.work, "mexe no deny", "agents/permissions/deny.json")
        items, _ = self.plan(self.work)
        (self.push,) = self.pushes(items)
        patcher = mock.patch.object(P, "other_hosts", return_value=["pi01"])
        patcher.start()
        self.addCleanup(patcher.stop)

    def fact(self, **kw):
        home = "/home/u"
        return {"alias": "pi01", "alvo": "pi01", "slug": "o/r", "path": home + "/dotfiles", "home": home,
                "behind": 0, "ahead": 0, "dirty": 0, "head": self.pre, "up": self.pre,
                "upname": "origin/main", **kw}

    def hosts(self, fact):
        return P.plan_hosts(True, ["o/r"], [fact], {"o/r": str(self.work)}, [self.push])

    def test_host_em_dia_ganha_pull_e_setup_que_dependem_do_push(self):
        items, fora = self.hosts(self.fact())
        self.assertEqual(fora, [])
        pull, setup = items
        self.assertIs(pull["dep"], self.push)
        self.assertIs(setup["dep"], pull)
        self.assertIn("agents/permissions/deny.json", setup["why"])

    def test_o_diff_vem_do_head_local_e_nao_do_upstream_do_host(self):
        # O `up` do host é o commit antigo: sem o HEAD local o diff sairia vazio.
        items, _ = self.hosts(self.fact(up=self.pre))
        self.assertEqual(len(items), 2)

    def test_host_que_segue_outra_branch_nao_ganha_previsao(self):
        self.assertEqual(self.hosts(self.fact(upname="origin/outra")), ([], []))

    def test_commit_do_host_desconhecido_no_clone_local_sai_do_plano(self):
        items, fora = self.hosts(self.fact(head="0" * 40, up="0" * 40))
        self.assertEqual(items, [])
        self.assertEqual(len(fora), 1)
        self.assertIn("não existe no clone local", fora[0])

    def test_host_com_head_fora_do_historico_do_push_sai_do_plano(self):
        git(self.work, "checkout", "-q", "-b", "lateral", self.pre)
        self.commit(self.work, "lateral")
        lateral = git(self.work, "rev-parse", "HEAD")
        git(self.work, "checkout", "-q", "main")
        items, fora = self.hosts(self.fact(head=lateral, up=lateral))
        self.assertEqual(items, [])
        self.assertEqual(len(fora), 1)


if __name__ == "__main__":
    unittest.main()
