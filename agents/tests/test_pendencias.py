"""Testes do `agents/skills/fechar/scripts/pendencias --plano`: o item de push, o
pull e o setup do outro host que dependem dele, e quando o diff pede `./setup.sh`;
o fast-forward do clone principal e a limpeza que depende dele; as redes do docker.

`decide_host`, `setup_reason` e `render_plan` são puras. O push, a limpeza e o diff
local precisam de git de verdade: cada teste monta um bare como `origin` num
diretório temporário. O docker é um falso no PATH."""

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
VAULT_VINCULOS = Path(__file__).resolve().parents[2] / "vault" / ".local" / "bin" / "vault-vinculos"
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
        items, fora = self.plan(self.work)
        self.assertEqual(self.pushes(items), [])
        self.assertEqual([i["cmd"] for i in items], ["git -C %s merge --ff-only origin/main" % P.shpath(str(self.work))])
        self.assertEqual(fora, [])

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


class PlanLimpeza(Repo):
    """O fast-forward do clone principal, os `worktree remove`/`branch -d` que dependem dele e o motivo de cada um."""

    def avanca_origin(self, subject="mergeado noutro lugar"):
        """Um commit novo no origin/main, visto pelo fetch, e o clone principal fica atrás."""
        outro = self.tmp / "outro"
        if not outro.exists():
            subprocess.run(["git", "clone", "-q", str(self.origin), str(outro)], check=True, capture_output=True)
        git(outro, "pull", "-q")
        self.commit(outro, subject)
        git(outro, "push", "-q")
        git(self.work, "fetch", "-q")

    def sub_branch_mergeada(self, branch):
        """Worktree de uma sub-branch sem upstream que o PR levou ao origin/main, com o principal parado antes dele:
        o `branch -d` só aceita depois do fast-forward (as `issue-105-*` do bjju-vision em 21/10)."""
        wt = self.worktree(branch)
        self.commit(wt, "da " + branch)
        git(wt, "push", "-q", "origin", "%s:main" % branch)
        git(self.work, "fetch", "-q")
        return wt

    def ff_cmd(self):
        return "git -C %s merge --ff-only origin/main" % P.shpath(str(self.work))

    def by_cmd(self, items, needle):
        (found,) = [i for i in items if needle in i["cmd"]]
        return found

    def test_principal_atras_e_limpo_ganha_o_fast_forward(self):
        self.avanca_origin()
        (self.work / "novo.txt").write_text("arquivo novo não impede\n")
        items, fora = self.plan(self.work)
        (ff,) = items
        self.assertEqual(ff["cmd"], self.ff_cmd())
        self.assertIn("1 commit atrás de origin/main", ff["why"])
        self.assertEqual(fora, [])

    def test_sem_rede_o_fast_forward_vai_ate_onde_o_fetch_viu(self):
        self.avanca_origin()
        self.assertEqual([i["cmd"] for i in self.plan(self.work, net=False)[0]], [self.ff_cmd()])

    def test_arquivo_rastreado_modificado_tira_o_fast_forward(self):
        self.avanca_origin()
        (self.work / "inicial.txt").write_text("mexido\n")
        items, fora = self.plan(self.work)
        self.assertEqual(items, [])
        (motivo,) = fora
        self.assertIn("arquivo rastreado modificado", motivo)

    def test_principal_fora_da_branch_padrao_ou_divergido_nao_ganha_fast_forward(self):
        self.avanca_origin()
        git(self.work, "checkout", "-q", "-b", "outra")
        self.assertEqual(self.plan(self.work), ([], []))
        git(self.work, "checkout", "-q", "main")
        self.commit(self.work, "local")
        items, fora = self.plan(self.work)
        self.assertEqual(items, [])
        self.assertNotIn("fast-forward", " ".join(fora))

    def test_worktree_que_so_sai_depois_do_fast_forward_depende_dele(self):
        wt = self.sub_branch_mergeada("sub")
        items, fora = self.plan(self.work)
        self.assertEqual(fora, [])
        ff = self.by_cmd(items, "merge --ff-only")
        rm = self.by_cmd(items, "worktree remove")
        self.assertIs(rm["dep"], ff)
        lines = P.render_plan(items, fora)
        self.assertTrue(lines[0].startswith("P1. " + self.ff_cmd()))
        self.assertIn("depende do fast-forward (P1)", lines[1])
        # Rodados na ordem do plano, o git aceita os dois.
        for it in (ff, rm):
            subprocess.run(["bash", "-c", it["cmd"]], check=True, capture_output=True)
        self.assertFalse(wt.exists())
        self.assertEqual(git(self.work, "branch", "--list", "sub"), "")

    def test_branch_fora_de_worktree_que_so_sai_depois_do_fast_forward_depende_dele(self):
        wt = self.sub_branch_mergeada("sub")
        git(self.work, "worktree", "remove", str(wt))
        items, _ = self.plan(self.work)
        self.assertIs(self.by_cmd(items, "branch -d sub")["dep"], self.by_cmd(items, "merge --ff-only"))

    def test_sem_fast_forward_possivel_a_worktree_fica_fora(self):
        self.sub_branch_mergeada("sub")
        (self.work / "inicial.txt").write_text("mexido\n")
        items, fora = self.plan(self.work)
        self.assertEqual(items, [])
        self.assertIn("atualize o clone principal antes", " ".join(fora))

    def test_worktree_de_outra_sessao_entra_e_o_motivo_so_informa(self):
        wt = self.worktree("feita")
        self.commit(wt, "da feita")
        git(wt, "push", "-q", "-u", "origin", "feita")
        git(self.work, "merge", "-q", "--ff-only", "feita")
        git(self.work, "push", "-q")
        (rm,) = self.plan(self.work)[0]
        self.assertIn("worktree remove", rm["cmd"])
        self.assertIsNone(rm["dep"])
        self.assertFalse(rm["last"])
        self.assertIn("worktree [feita] de outra sessão já está em origin/main", rm["why"])
        (rm,) = self.plan(self.work, wt)[0]
        self.assertTrue(rm["last"])
        self.assertIn("desta sessão", rm["why"])

    def test_o_motivo_nomeia_todo_arquivo_ignorado_avulso_e_resume_as_pastas(self):
        wt = self.worktree("ign")
        avulsos = [".env", ".impeccable/hook.cache.json", "a.log", "b.log", "c.log", "d.log"]
        pastas = ["build", "dist", "node_modules", "out", "target"]
        self.commit(wt, "gitignore", ".gitignore")
        (wt / ".gitignore").write_text("\n".join([".env", "hook.cache.json", "*.log"] + [p + "/" for p in pastas]) + "\n")
        git(wt, "commit", "-q", "-am", "ignora")
        git(wt, "push", "-q", "origin", "ign:main")
        git(self.work, "pull", "-q")
        for f in avulsos + [p + "/x" for p in pastas]:
            (wt / f).parent.mkdir(parents=True, exist_ok=True)
            (wt / f).write_text("x\n")
        (rm,) = self.plan(self.work)[0]
        self.assertIn("os arquivos ignorados %s" % ", ".join(sorted(avulsos)), rm["why"])
        self.assertIn("as pastas ignoradas build/, dist/, node_modules/, out/, …", rm["why"])

    def test_nunca_forca_nem_poda(self):
        self.sub_branch_mergeada("sub")
        for text in [i["cmd"] for i in self.plan(self.work)[0]]:
            self.assertNotRegex(text, r"--force| -D |prune")


class PlanDocker(unittest.TestCase):
    """As redes vêm de um `docker` falso no PATH: `network ls` e `ps --all`, como o script os chama."""

    def docker(self, redes, usadas, rc=0):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        fake = Path(tmp.name) / "docker"
        fake.write_text('#!/bin/sh\ncase "$1" in network) printf %%s %s ;; ps) printf %%s %s ;; esac\nexit %d\n'
                        % (shlex.quote("\n".join(redes)), shlex.quote("\n".join(usadas)), rc))
        fake.chmod(0o755)
        patcher = mock.patch.dict(os.environ, {"PATH": tmp.name + os.pathsep + "/usr/bin:/bin"})
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_rede_sem_container_nenhum_vira_um_item_so(self):
        # `parada` só tem container parado; `bridge`, `host` e `none` são do docker.
        self.docker(["bridge", "host", "none", "a_default", "parada", "b_default"], ["parada", "bridge,parada", ""])
        (rm,), fora = P.plan_docker()
        self.assertEqual(rm["cmd"], "docker network rm a_default b_default")
        self.assertIn("2 redes do docker", rm["why"])
        self.assertEqual(fora, [])
        self.assertNotRegex(rm["cmd"], r"--force|-f |prune")

    def test_toda_rede_com_container_nao_propoe_nada(self):
        self.docker(["bridge", "host", "none", "a"], ["a"])
        self.assertEqual(P.plan_docker(), ([], []))

    def test_docker_que_falha_diz_que_nao_consultou(self):
        self.docker(["a"], [], rc=1)
        self.assertEqual(P.plan_docker(), ([], ["docker: não consultei as redes (o docker não respondeu)"]))

    def test_sem_docker_nada(self):
        with mock.patch.object(P.shutil, "which", return_value=None):
            self.assertEqual(P.plan_docker(), ([], []))


class PlanHosts(Repo):
    """O host que fica atrás depois do push: o diff é `HEAD do host..HEAD local`."""

    def setUp(self):
        super().setUp()
        self.pre = git(self.work, "rev-parse", "HEAD")
        self.commit(self.work, "mexe no deny", "agents/permissions/deny.json")
        items, _ = self.plan(self.work)
        (self.push,) = self.pushes(items)
        patcher = mock.patch.object(P, "other_hosts", return_value=[["pi01", "pi01-local"]])
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


class Vinculos(unittest.TestCase):
    """Os vínculos vêm do `vault-vinculos` do repo, num HOME de fixture e sem freitask no PATH."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.home = Path(os.path.realpath(tmp.name))
        bin_dir = self.home / "bin"
        bin_dir.mkdir()
        (bin_dir / "vault-vinculos").symlink_to(VAULT_VINCULOS)
        path = [d for d in os.environ["PATH"].split(os.pathsep) if not os.access(os.path.join(d, "freitask"), os.X_OK)]
        patcher = mock.patch.dict(os.environ, {
            **GIT_ENV, "HOME": str(self.home), "VAULT_HOSTNAME": "notebook",
            "GIT_CEILING_DIRECTORIES": str(self.home), "PATH": os.pathsep.join([str(bin_dir)] + path)})
        patcher.start()
        self.addCleanup(patcher.stop)
        self.vault = self.home / "ObsidianVault"
        (self.vault / "projects" / "workflow-ia" / "tasks").mkdir(parents=True)

    def repo(self, name, contract):
        root = self.home / "dev" / name
        subprocess.run(["git", "init", "-q", "-b", "main", str(root)], check=True)
        (root / "docs" / "agents").mkdir(parents=True)
        (root / "docs" / "agents" / "domain.md").write_text(contract + "\n")
        git(root, "add", "-A")
        git(root, "commit", "-q", "-m", "inicial")
        return root

    def test_contrato_que_cita_so_a_pasta_do_projeto_o_alimenta(self):
        # O ~/dev/freitask.nvim de 20/10 cita projects/workflow-ia/ e nenhum tasks/.
        root = self.repo("freitask.nvim", "O porquê mora em `~/ObsidianVault/projects/workflow-ia/`.")
        self.assertEqual(P.contract_projects(str(root)), {"workflow-ia"})

    def test_worktree_responde_pelo_clone_principal(self):
        root = self.repo("r", "projects/workflow-ia/tasks")
        wt = self.home / "wt"
        git(root, "worktree", "add", "-q", "-b", "wt", str(wt))
        self.assertEqual(P.main_clone(str(wt)), str(root))
        self.assertEqual(P.contract_projects(str(wt)), {"workflow-ia"})

    def test_outras_maquinas_com_os_aliases_em_ordem(self):
        hosts = self.vault / "hosts"
        hosts.mkdir()
        (hosts / "notebook-de-casa.md").write_text("# NoteBook — esta máquina\n")
        (hosts / "servidor.md").write_text("# srv01 — servidor\n")
        self.assertEqual(P.other_hosts(), [["srv01", "srv01-local"]])

    def sem_vault_vinculos(self):
        return os.pathsep.join(d for d in os.environ["PATH"].split(os.pathsep)
                               if not os.access(os.path.join(d, "vault-vinculos"), os.X_OK))

    def vault_vinculos_quebrado(self):
        quebrado = self.home / "quebrado"
        quebrado.mkdir(exist_ok=True)
        (quebrado / "vault-vinculos").write_text("#!/bin/sh\necho lixo\nexit 2\n")
        (quebrado / "vault-vinculos").chmod(0o755)
        return os.pathsep.join([str(quebrado), os.environ["PATH"]])

    def test_sem_resposta_do_vault_vinculos_as_secoes_dizem_que_ele_falta(self):
        self.assertEqual(P.sem_vinculos("x"), [])
        for path in (self.sem_vault_vinculos(), self.vault_vinculos_quebrado()):
            with self.subTest(path=path), mock.patch.dict(os.environ, {"PATH": path}):
                self.assertIn("o vault-vinculos não respondeu", P.report_hosts(["o/r"], True)[0])
                self.assertIn("o vault-vinculos não respondeu", P.report_registro(set())[0])

    def test_sem_resposta_do_vault_vinculos_o_plano_diz_que_nao_sabe_as_outras_maquinas(self):
        with mock.patch.dict(os.environ, {"PATH": self.vault_vinculos_quebrado()}):
            _, fora = P.plan_hosts(True, ["o/r"], [], {})
        self.assertEqual(fora, [P.falta_vinculos("quais são as outras máquinas")])

    def plano_de_um_worktree(self, path):
        """A seção `## plano` rodada de um worktree de um clone com origin, com este PATH."""
        origin = self.home / "origin.git"
        subprocess.run(["git", "init", "-q", "--bare", "-b", "main", str(origin)], check=True)
        root = self.repo("r", "projects/workflow-ia/tasks")
        git(root, "remote", "add", "origin", str(origin))
        git(root, "push", "-q", "-u", "origin", "main")
        git(root, "remote", "set-head", "origin", "main")
        wt = self.home / "wt"
        git(root, "worktree", "add", "-q", "-b", "feat", str(wt))
        out = subprocess.run([sys.executable, "-I", str(SCRIPT), "--sem-rede", "--plano"], cwd=wt,
                             env={**os.environ, "PATH": path, "XDG_RUNTIME_DIR": str(self.home)},
                             capture_output=True, text=True, check=True).stdout
        return out.split("## plano", 1)[1]

    def test_sem_vault_vinculos_no_path_nao_ha_plano(self):
        # Sem o clone principal, o worktree passaria por principal e o plano mandaria remover o principal.
        plano = self.plano_de_um_worktree(self.sem_vault_vinculos())
        self.assertIn("o vault-vinculos não respondeu", plano)
        self.assertNotIn("worktree remove", plano)

    def test_vault_vinculos_que_falha_tambem_suspende_o_plano(self):
        plano = self.plano_de_um_worktree(self.vault_vinculos_quebrado())
        self.assertIn("o vault-vinculos não respondeu", plano)
        self.assertNotIn("worktree remove", plano)

    def test_com_vault_vinculos_o_plano_segue(self):
        self.assertNotIn("o vault-vinculos não respondeu", self.plano_de_um_worktree(os.environ["PATH"]))


if __name__ == "__main__":
    unittest.main()
