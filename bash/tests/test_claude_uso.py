"""Testes do `bash/.local/bin/claude-uso` num diretório `--projetos` sintético.

Dois dias (2026-03-02 e 2026-03-03, no fuso UTC), uma requisição repetida em duas
linhas (o dedupe por requestId), dois subagentes com meta.json, um prompt, um
tool_result e uma saída de comando local que não contam, e um modelo sem preço.
O `vault-vinculos` é um falso no PATH que lista um repo de fixture com um commit;
o PATH só tem o falso e o git, então o `gh` falta de propósito."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / ".local" / "bin" / "claude-uso"
DIA1, DIA2 = "2026-03-02", "2026-03-03"


def linha(**campos):
    return json.dumps(campos, ensure_ascii=False)


def assistente(rid, ts, modelo, usage, blocos):
    return linha(
        type="assistant", timestamp=ts, requestId=rid,
        message={"model": modelo, "usage": usage, "content": blocos},
    )


def uso(entrada=0, escrita=0, leitura=0, saida=0):
    return {
        "input_tokens": entrada, "cache_creation_input_tokens": escrita,
        "cache_read_input_tokens": leitura, "output_tokens": saida,
    }


M = 1_000_000


class ClaudeUsoTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp())
        t = cls.tmp
        proj = t / "projetos" / "-proj"
        sess = proj / "sessao1"
        (sess / "subagents").mkdir(parents=True)
        ts1, ts2 = f"{DIA1}T12:00:00.000Z", f"{DIA2}T12:00:00.000Z"
        principal = [
            linha(type="ai-title", aiTitle="Sessão de teste", sessionId="sessao1"),
            linha(type="user", timestamp=ts1, promptId="p1", message={"role": "user", "content": "oi"}),
            linha(type="user", timestamp=ts1, promptId="p1x",
                  message={"role": "user", "content": [
                      {"type": "tool_result", "tool_use_id": "t0", "content": "ok"}]}),
            linha(type="user", timestamp=ts1, promptId="p1y",
                  message={"role": "user", "content": "<local-command-stdout>x</local-command-stdout>"}),
            # a mesma requisição r1, em duas linhas (um bloco por linha)
            assistente("r1", ts1, "claude-opus-5-5", uso(M, M, M, M),
                       [{"type": "text", "text": "feito"}]),
            assistente("r1", ts1, "claude-opus-5-5", uso(M, M, M, M),
                       [{"type": "tool_use", "id": "t1", "name": "Edit", "input": {}}]),
            linha(type="user", timestamp=ts2, promptId="p2",
                  message={"role": "user", "content":
                           "<command-name>/x</command-name><command-args>ola</command-args>"}),
            assistente("r2", ts2, "claude-sonnet-5-5", uso(0, 0, M, M),
                       [{"type": "text", "text": "ok"}]),
        ]
        (proj / "sessao1.jsonl").write_text("\n".join(principal) + "\n")
        sub1 = [
            assistente("r3", ts1, "claude-fable-5-2", uso(M, 0, 0, M),
                       [{"type": "tool_use", "id": "t2", "name": "Bash", "input": {}}]),
        ]
        sub2 = [assistente("r4", ts2, "claude-foo-1", uso(10, 0, 0, 10), [])]
        for nome, tipo, linhas in (("a1", "implementador", sub1), ("a2", "revisor", sub2)):
            (sess / "subagents" / f"agent-{nome}.jsonl").write_text("\n".join(linhas) + "\n")
            (sess / "subagents" / f"agent-{nome}.meta.json").write_text(json.dumps({"agentType": tipo}))

        repo = t / "repo"
        repo.mkdir()
        git_env = {
            **os.environ, "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
            "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t",
            "GIT_AUTHOR_DATE": f"{DIA1}T12:00:00+00:00", "GIT_COMMITTER_DATE": f"{DIA1}T12:00:00+00:00",
        }
        (repo / "a.txt").write_text("1\n2\n3\n")
        for cmd in (["init", "-q"], ["add", "."], ["commit", "-q", "-m", "um"]):
            subprocess.run(["git", *cmd], cwd=repo, env=git_env, check=True, capture_output=True)

        bin_ = t / "bin"
        bin_.mkdir()
        os.symlink(shutil.which("git"), bin_ / "git")
        falso = bin_ / "vault-vinculos"
        falso.write_text(f"#!/bin/sh\nprintf '%s\\t%s\\t\\n' '{repo}' '{repo}'\n")
        falso.chmod(0o755)

        estado = t / "estado" / "claude-statusline"
        estado.mkdir(parents=True)
        (estado / "uso.tsv").write_text(
            "quando\t5h_pct\t5h_reset\t7d_pct\t7d_reset\tmodelo\tsessao\tcusto_sessao_usd\n"
            f"{DIA1}T10:00:00-03:00\t10\t1\t20\t1\tm\ts\t1\n"
            f"{DIA1}T11:00:00-03:00\t30\t1\t25\t1\tm\ts\t1\n"
            f"{DIA2}T11:00:00-03:00\t5\t1\t26\t1\tm\ts\t1\n"
        )
        cls.env = {
            "PATH": str(bin_), "TZ": "UTC", "HOME": str(t / "home"),
            "XDG_STATE_HOME": str(t / "estado"), "LC_ALL": "C.UTF-8",
        }

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def roda(self, *args, projetos=None):
        r = subprocess.run(
            [sys.executable, "-I", str(SCRIPT), *args, "--projetos", str(projetos or self.tmp / "projetos")],
            capture_output=True, text=True, env=self.env,
        )
        self.assertEqual(r.returncode, 0, r.stderr)
        return r.stdout

    @staticmethod
    def linhas(saida):
        """{primeira coluna: [demais colunas]} das linhas da tabela."""
        return {p[0]: p[1:] for p in (l.split() for l in saida.splitlines()) if p}

    def test_dias_dedupe_e_contagens(self):
        saida = self.roda("dias")
        self.assertTrue(saida.startswith("Custo é equivalente de API pela tabela de preços (2026-11-03)"))
        t = self.linhas(saida)
        cab = t["dia"]
        col = lambda dia, nome: t[dia][cab.index(nome)]
        # dia 1: r1 (opus, 32.20, contada uma vez) + r3 (fable, subagente, 48.00)
        self.assertEqual(col(DIA1, "custo"), "$80.20")
        self.assertEqual(col(DIA1, "%sub"), "60%")
        self.assertEqual(col(DIA1, "fable"), "$48.00")
        self.assertEqual(col(DIA1, "prompts"), "1")  # tool_result e comando local não contam
        self.assertEqual(col(DIA1, "tools"), "2")
        self.assertEqual(col(DIA1, "edits"), "1")
        self.assertEqual(col(DIA1, "ctx_k"), "3000")  # (1M+1M+1M) numa requisição
        self.assertEqual(col(DIA1, "commits"), "1")
        self.assertEqual(col(DIA1, "lin+"), "3")
        self.assertEqual(col(DIA1, "lin-"), "0")
        self.assertEqual(col(DIA1, "PRs"), "-")  # sem gh
        # dia 2: r2 (sonnet, 0.10 + 10.00); r4 (modelo sem preço) fica fora do custo
        self.assertEqual(col(DIA2, "custo"), "$10.10")
        self.assertEqual(col(DIA2, "%sub"), "0%")
        self.assertEqual(col(DIA2, "prompts"), "1")  # o comando de barra conta
        self.assertEqual(col(DIA2, "ctx_k"), "1000")
        self.assertEqual(col(DIA2, "commits"), "0")
        self.assertEqual(col("total", "custo"), "$90.30")
        self.assertIn("1 requisições sem preço", saida)
        self.assertIn("claude-foo-1 (1)", saida)
        self.assertIn("gh não está no PATH", saida)

    def test_semanas_e_o_padrao_sem_argumento(self):
        padrao = self.roda()
        t = self.linhas(padrao)
        self.assertEqual(self.roda("semanas"), padrao)
        self.assertEqual(t["2026-W10"][t["semana"].index("custo")], "$90.30")
        self.assertEqual(t["2026-W10"][t["semana"].index("dias")], "2")

    def test_desde_corta_o_dia_anterior(self):
        saida = self.roda("dias", "--desde", DIA2)
        self.assertNotIn(DIA1, saida)
        self.assertIn(DIA2, saida)

    def test_subagentes_por_tipo_e_modelo_real(self):
        t = self.linhas(self.roda("subagentes"))
        self.assertEqual(t["implementador"][:4], ["$48.00", "100%", "1", "fable-5-2"])
        self.assertEqual(t["implementador"][4], "1")
        self.assertEqual(t["revisor"][:3], ["$0.00", "0%", "1"])
        self.assertEqual(t["revisor"][3:], ["foo-1", "1"])
        self.assertEqual(t["total"][:3], ["$48.00", "100%", "2"])

    def test_modelos_lista_a_sessao_principal(self):
        saida = self.roda("modelos", "--modelo", "sonnet")
        self.assertIn("$10.10", saida)
        self.assertIn("Sessão de teste", saida)
        self.assertIn("sessao1.jsonl", saida)
        self.assertIn(DIA2, saida)
        self.assertIn("Nenhuma sessão principal", self.roda("modelos"))  # nenhuma usou Fable

    def test_plano_maximo_por_dia(self):
        t = self.linhas(self.roda("plano"))
        self.assertEqual(t[DIA1], ["30%", "25%"])
        self.assertEqual(t[DIA2], ["5%", "26%"])

    def test_plano_sem_arquivo_diz_de_onde_vem(self):
        r = subprocess.run(
            [sys.executable, "-I", str(SCRIPT), "plano"],
            capture_output=True, text=True, env={**self.env, "XDG_STATE_HOME": str(self.tmp / "nada")},
        )
        self.assertEqual(r.returncode, 0)
        self.assertIn("statusline", r.stdout)

    def test_help_descreve_subcomandos_e_colunas(self):
        saida = self.roda("--help")
        for termo in ("semanas", "dias", "subagentes", "modelos", "plano", "ctx_k", "$/PR", "--projetos"):
            self.assertIn(termo, saida)

    def test_desde_invalido_e_erro_de_uso(self):
        r = subprocess.run(
            [sys.executable, "-I", str(SCRIPT), "dias", "--desde", "ontem"],
            capture_output=True, text=True, env=self.env,
        )
        self.assertEqual(r.returncode, 2)


if __name__ == "__main__":
    unittest.main()
