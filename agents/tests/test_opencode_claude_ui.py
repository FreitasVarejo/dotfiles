"""O plugin `claude-ui` do OpenCode (agents/opencode/plugins/claude-ui/): a lógica do rodapé (`rodape.ts`) e a dos
diálogos (`dialogos.ts`).

O OpenCode só carrega o plugin de verdade na partida do TUI; aqui a lógica roda no Node, que apaga os tipos do
TypeScript, contra as travas de verdade (`agents/travas/`) num repo, vault e runtime temporários. A cola
(`tui.tsx`) é JSX do OpenCode e não roda no Node: o teste confere só que ela importa o que os módulos exportam.
Cada teste monta HOME e estado temporários: nada do $HOME real entra na conta."""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
PKG = Path(__file__).resolve().parents[1]
PLUGIN = PKG / "opencode" / "plugins" / "claude-ui"
TRAVAS = PKG / "travas"
NODE = shutil.which("node")
GIT_ENV = {
    "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1",
    "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t",
}
SESSAO = "ses_teste123"


@unittest.skipUnless(NODE, "node não encontrado: o plugin só se testa com ele")
class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="oc-claude-ui-")).resolve()
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.home = self.tmp / "home"
        self.home.mkdir()
        self.env = {**os.environ, **GIT_ENV, "HOME": str(self.home)}

    def js(self, module, body, env=None):
        """Roda `body` (módulo ESM) com `m` = o módulo do plugin; o que ele imprime é JSON."""
        script = 'import * as m from "%s"\n%s' % ((PLUGIN / module).as_uri(), body)
        done = subprocess.run(
            [NODE, "--no-warnings", "--input-type=module", "-e", script],
            capture_output=True, text=True, env=env or self.env, timeout=60,
        )
        self.assertEqual(done.returncode, 0, done.stderr)
        return json.loads(done.stdout)


class Faixa(Base):
    """O texto é o do mod `agents/mods/travas-pendentes` do Claude Code."""

    def faixa(self, pendentes):
        return self.js("rodape.ts", "console.log(JSON.stringify(m.faixa(%s, %s) ?? null))"
                       % (json.dumps(pendentes), json.dumps(str(self.home))))

    def test_nada_pendente_nao_tem_faixa(self):
        self.assertIsNone(self.faixa({"verificar": [], "doctor": False}))

    def test_verificar_num_repo_no_singular_e_no_plural(self):
        raiz = str(self.home / "dotfiles")
        self.assertEqual(self.faixa({"verificar": [{"root": raiz, "files": 1}], "doctor": False}),
                         "o Stop cobra: /verificar em ~/dotfiles (1 arquivo)")
        self.assertEqual(self.faixa({"verificar": [{"root": raiz, "files": 3}], "doctor": False}),
                         "o Stop cobra: /verificar em ~/dotfiles (3 arquivos)")

    def test_repo_fora_do_home_fica_inteiro_e_o_doctor_vem_depois(self):
        self.assertEqual(
            self.faixa({"verificar": [{"root": "/srv/x", "files": 2}, {"root": str(self.home / "a"), "files": 1}],
                        "doctor": True}),
            "o Stop cobra: /verificar em /srv/x (2 arquivos) · /verificar em ~/a (1 arquivo)"
            " · freitask doctor (vault tocado)")

    def test_so_o_doctor(self):
        self.assertEqual(self.faixa({"verificar": [], "doctor": True}), "o Stop cobra: freitask doctor (vault tocado)")

    def test_parse_da_saida_de_pendente(self):
        out = self.js("rodape.ts", 'console.log(JSON.stringify(m.parseVerificar("2\\t/r/a\\n\\n1\\t/r/b\\nlixo\\n")))')
        self.assertEqual(out, [{"root": "/r/a", "files": 2}, {"root": "/r/b", "files": 1}])


class Linha(Base):
    def test_k_e_contexto_como_a_statusline_do_claude(self):
        out = self.js("rodape.ts", """console.log(JSON.stringify([
            m.k(999), m.k(1000), m.k(123456), m.k(1000000), m.k(2500000),
            m.contexto(123456, 1000000), m.contexto(undefined, 1000000), m.contexto(50, undefined),
            m.contexto(undefined, undefined) ?? null,
        ]))""")
        self.assertEqual(out, ["999", "1k", "123.4k", "1M", "2.5M",
                               "ctx 123.4k/1M 12%", "ctx -/1M", "ctx 50", None])

    def test_tokens_em_uso_ignora_o_que_veio_antes_da_compactacao(self):
        def tok(n):
            return {"input": n, "output": 1, "reasoning": 0, "cache": {"read": 2, "write": 3}}
        mensagens = [
            {"type": "assistant", "tokens": tok(100)},
            {"type": "compaction", "status": "completed"},
            {"type": "user"},
        ]
        out = self.js("rodape.ts", "console.log(JSON.stringify([m.tokensEmUso(%s) ?? null, m.tokensEmUso(%s), m.tokensEmUso([]) ?? null]))"
                      % (json.dumps(mensagens), json.dumps(mensagens[:1] + [{"type": "assistant", "tokens": tok(7)}])))
        self.assertEqual(out, [None, 7 + 1 + 2 + 3, None])


class Uso(Base):
    """`/api/experimental/usage/limits` é a rota do OpenCode Console: sem resposta para o modelo, nada no rodapé."""

    def uso(self, info, model, provider):
        return self.js("rodape.ts", "console.log(JSON.stringify(m.usoDaAssinatura(%s, %s, %s) ?? null))"
                       % (json.dumps(info), json.dumps(model), json.dumps(provider)))

    def info(self, **budget):
        base = {"coverage": "all", "per": "set", "limit": 20, "spent": 7.5, "models": []}
        return {"budgets": [{**base, **budget}]}

    PAGO = {"id": "m1", "providerID": "opencode", "cost": [{"input": 3}]}
    CONSOLE = {"id": "opencode", "integrationID": "opencode"}

    def test_rota_sem_dado_nao_mostra_nada(self):
        self.assertIsNone(self.uso(None, self.PAGO, self.CONSOLE))
        self.assertIsNone(self.uso({"budgets": []}, self.PAGO, self.CONSOLE))

    def test_modelo_servido_pelo_console_mostra_o_que_resta(self):
        self.assertEqual(self.uso(self.info(), self.PAGO, self.CONSOLE), {"texto": "$12.50 left", "esgotado": False})

    def test_provedor_de_fora_nao_entra_no_orcamento_que_cobre_tudo(self):
        copilot = {"id": "github-copilot", "integrationID": "github-copilot"}
        modelo = {"id": "gpt", "providerID": "github-copilot", "cost": [{"input": 3}]}
        self.assertIsNone(self.uso(self.info(), modelo, copilot))

    def test_orcamento_que_nomeia_o_modelo_vale_para_qualquer_provedor(self):
        copilot = {"id": "github-copilot"}
        modelo = {"id": "gpt", "providerID": "github-copilot", "cost": [{"input": 3}]}
        info = self.info(coverage="models", models=[{"providerID": "github-copilot", "modelID": "gpt"}])
        self.assertEqual(self.uso(info, modelo, copilot), {"texto": "$12.50 left", "esgotado": False})

    def test_modelo_gratuito_e_orcamento_estourado(self):
        self.assertIsNone(self.uso(self.info(), {**self.PAGO, "cost": [{"input": 0}]}, self.CONSOLE))
        self.assertEqual(self.uso(self.info(spent=25), self.PAGO, self.CONSOLE), {"texto": "$0 left", "esgotado": True})

    def test_o_limite_mais_perto_de_acabar_manda(self):
        info = self.info()
        info["budgets"].append({**info["budgets"][0], "limit": 10, "spent": 9.995})
        self.assertEqual(self.uso(info, self.PAGO, self.CONSOLE)["texto"], "<$0.01 left")


class Ambiente(Base):
    """Repo com `docs/agents/verificacao.md`, vault e runtime temporários: o que as travas leem."""

    def setUp(self):
        super().setUp()
        self.vault = self.tmp / "vault"
        self.vault.mkdir()
        self.runtime = self.tmp / "rt"
        self.runtime.mkdir()
        self.repo = self.tmp / "repo"
        (self.repo / "docs" / "agents").mkdir(parents=True)
        (self.repo / "docs" / "agents" / "verificacao.md").write_text("```portoes\n*  true\n```\n")
        (self.repo / "a.txt").write_text("um\n")
        self.git("init", "-q")
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "base")
        # `freitask` falso: a trava do doctor só age onde ele existe.
        self.bin = self.tmp / "bin"
        self.bin.mkdir()
        (self.bin / "freitask").write_text("#!/bin/sh\n")
        (self.bin / "freitask").chmod(0o755)
        self.env.update({"TRAVAS_VAULT": str(self.vault), "XDG_RUNTIME_DIR": str(self.runtime),
                         "PATH": str(self.bin) + os.pathsep + os.environ["PATH"]})

    def git(self, *args):
        subprocess.run(["git", "-C", str(self.repo), *args], check=True, capture_output=True, env=self.env)

    def trava(self, script, *args, event=None):
        subprocess.run([sys.executable, "-I", str(TRAVAS / script), *args], input=json.dumps(event or {}),
                       text=True, capture_output=True, check=True, env=self.env)

    def edita(self, rel, text):
        caminho = self.repo / rel
        self.trava("verificacao-no-stop", "marca", event={"session_id": SESSAO, "tool_name": "Write",
                                                           "tool_input": {"file_path": str(caminho)}})
        caminho.write_text(text)

    def pendentes(self, sessao=SESSAO):
        return self.js("rodape.ts", "console.log(JSON.stringify(await m.pendentes(%s, %s)))"
                       % (json.dumps(sessao), json.dumps(str(TRAVAS) + "/")))


class Pendentes(Ambiente):
    def test_sem_toque_nada_pendente(self):
        self.assertEqual(self.pendentes(), {"verificar": [], "doctor": False})

    def test_edicao_sem_carimbo_volta_na_faixa_e_o_carimbo_a_apaga(self):
        self.edita("a.txt", "dois\n")
        self.edita("b.txt", "novo\n")
        self.assertEqual(self.pendentes(), {"verificar": [{"root": str(self.repo), "files": 2}], "doctor": False})
        self.trava("verificacao-no-stop", "carimba", str(self.repo))
        self.assertEqual(self.pendentes(), {"verificar": [], "doctor": False})

    def test_vault_tocado_pede_o_doctor(self):
        evento = {"session_id": SESSAO, "tool_name": "Write",
                  "tool_input": {"file_path": str(self.vault / "daily" / "x.md")}}
        self.trava("doctor-no-stop", "marca", event=evento)
        self.assertEqual(self.pendentes(), {"verificar": [], "doctor": True})

    def test_o_id_da_sessao_do_opencode_passa_intacto_e_outra_sessao_nao_enxerga(self):
        self.edita("a.txt", "dois\n")
        self.assertEqual(self.pendentes("ses_outra"), {"verificar": [], "doctor": False})
        marcadores = [p.name for p in (self.runtime / "claude-travas").iterdir()]
        self.assertTrue(any(SESSAO in nome for nome in marcadores), marcadores)

    def test_trava_que_falha_vira_nada_pendente(self):
        out = self.js("rodape.ts", "console.log(JSON.stringify(await m.pendentes(%s, %s)))"
                      % (json.dumps(SESSAO), json.dumps(str(self.tmp / "nao-existe") + "/")))
        self.assertEqual(out, {"verificar": [], "doctor": False})

    def test_o_diretorio_das_travas_sai_do_link_do_plugin(self):
        link = self.tmp / "config" / "plugins" / "claude-ui"
        link.parent.mkdir(parents=True)
        link.symlink_to(PLUGIN)
        out = self.js("rodape.ts", 'console.log(JSON.stringify(m.travasDir("%s")))' % (link / "rodape.ts").as_uri())
        self.assertEqual(Path(out), TRAVAS)


class Historico(Base):
    def escreve(self, linhas):
        estado = self.tmp / "state" / "opencode"
        estado.mkdir(parents=True)
        arquivo = estado / "prompt-history.jsonl"
        arquivo.write_text("\n".join(l if isinstance(l, str) else json.dumps(l) for l in linhas) + "\n")
        return arquivo

    def entrada(self, texto, **extra):
        return {"text": texto, "files": [], "agents": [], "skills": [], "pasted": [], "mode": "normal", **extra}

    def test_caminho_segue_o_xdg_state_home(self):
        out = self.js("dialogos.ts", "console.log(JSON.stringify([m.historicoPath({XDG_STATE_HOME: '/x/s'}, '/h'), m.historicoPath({}, '/h')]))")
        self.assertEqual(out, ["/x/s/opencode/prompt-history.jsonl", "/h/.local/state/opencode/prompt-history.jsonl"])

    def test_leitura_pula_linha_torta_e_arquivo_ausente(self):
        arquivo = self.escreve([self.entrada("um"), "{torta", json.dumps({"sem": "texto"}), self.entrada("dois")])
        corpo = "const e = await m.lerHistorico(%s)\nconsole.log(JSON.stringify(e.map((x) => x.text)))"
        self.assertEqual(self.js("dialogos.ts", corpo % json.dumps(str(arquivo))), ["um", "dois"])
        self.assertEqual(self.js("dialogos.ts", "console.log(JSON.stringify(await m.lerHistorico(%s)))"
                                 % json.dumps(str(self.tmp / "nada.jsonl"))), [])

    def opcoes(self, entradas):
        return self.js("dialogos.ts", "console.log(JSON.stringify(m.opcoesDoHistorico(%s)))" % json.dumps(entradas))

    def test_a_mais_nova_vem_primeiro_sem_repetir_texto(self):
        out = self.opcoes([self.entrada("velho"), self.entrada("meio"), self.entrada("velho"), self.entrada("   ")])
        self.assertEqual([o["value"] for o in out], ["velho", "meio"])

    def test_prompt_de_varias_linhas_mostra_a_primeira_e_o_total(self):
        out = self.opcoes([self.entrada("\n  explica o rebase\ncom exemplo\nde tres")])
        self.assertEqual(out[0]["title"], "explica o rebase")
        self.assertEqual(out[0]["value"], "\n  explica o rebase\ncom exemplo\nde tres")
        self.assertEqual(out[0]["footer"], "4 linhas")

    def test_titulo_comprido_e_cortado_e_shell_leva_o_ponto_de_exclamacao(self):
        out = self.opcoes([self.entrada("x" * 300), self.entrada("ls -la", mode="shell")])
        self.assertEqual(out[0]["title"], "! ls -la")
        self.assertEqual(len(out[1]["title"]), 100)
        self.assertTrue(out[1]["title"].endswith("…"))

    def test_texto_colado_volta_ao_conteudo_real_so_onde_o_rotulo_esta(self):
        rotulo = "[Pasted ~2 lines]"
        entrada = self.entrada("veja " + rotulo + " ok", pasted=[
            {"text": "linha1\nlinha2", "source": {"start": 5, "end": 5 + len(rotulo), "text": rotulo}}])
        torta = self.entrada("veja outra coisa", pasted=[
            {"text": "XXX", "source": {"start": 5, "end": 10, "text": rotulo}}])
        out = self.js("dialogos.ts", "console.log(JSON.stringify([m.expandir(%s), m.expandir(%s)]))"
                      % (json.dumps(entrada), json.dumps(torta)))
        self.assertEqual(out, ["veja linha1\nlinha2 ok", "veja outra coisa"])

    def test_busca_por_palavras_em_qualquer_ordem_sem_caixa_e_no_texto_inteiro(self):
        opcoes = self.opcoes([self.entrada("explica o Rebase\ncom exemplo"), self.entrada("instala o ripgrep"),
                              self.entrada("rebase do bjju")])
        def busca(q):
            return self.js("dialogos.ts", "console.log(JSON.stringify(m.buscarNoHistorico(%s, %s).map((o) => o.value)))"
                           % (json.dumps(q), json.dumps(opcoes)))
        self.assertEqual(busca("REBASE"), ["rebase do bjju", "explica o Rebase\ncom exemplo"])
        self.assertEqual(busca("exemplo rebase"), ["explica o Rebase\ncom exemplo"])
        self.assertEqual(busca("  "), ["rebase do bjju", "instala o ripgrep", "explica o Rebase\ncom exemplo"])
        self.assertEqual(busca("nada disso"), [])


class Aprovacoes(Base):
    SALVAS = [
        {"id": "psv_2", "projectID": "p", "action": "shell", "resource": "ls *", "time": {"created": 1794500340993, "updated": 1}},
        {"id": "psv_1", "projectID": "p", "action": "edit", "resource": "*", "time": {"created": 1794500340993, "updated": 1}},
        {"id": "psv_3", "projectID": "p", "action": "shell", "resource": "echo *", "time": {"created": 1794500340993, "updated": 1}},
    ]

    def test_opcoes_por_acao_e_depois_por_recurso_com_o_id_como_valor(self):
        out = self.js("dialogos.ts", "console.log(JSON.stringify(m.opcoesDasSalvas(%s)))" % json.dumps(self.SALVAS))
        self.assertEqual([o["value"] for o in out], ["psv_1", "psv_3", "psv_2"])
        self.assertEqual([o["title"] for o in out], ["edit  *", "shell  echo *", "shell  ls *"])
        self.assertRegex(out[0]["description"], r"^salva em \d{4}-\d{2}-\d{2}$")

    def test_a_confirmacao_diz_o_que_volta_a_ser_perguntado(self):
        out = self.js("dialogos.ts", "console.log(JSON.stringify(m.confirmacaoDeRemocao(%s)))" % json.dumps(self.SALVAS[0]))
        self.assertIn('"shell ls *"', out)
        self.assertIn("volta a perguntar", out)


class Cola(unittest.TestCase):
    """`tui.tsx` é JSX do OpenCode e não roda no Node: aqui, só que o que ela importa existe."""

    def exportados(self, arquivo):
        texto = (PLUGIN / arquivo).read_text(encoding="utf-8")
        return set(re.findall(r"^export (?:async )?(?:function|const|type) (\w+)", texto, re.M))

    def test_tudo_que_a_cola_importa_dos_modulos_existe(self):
        cola = (PLUGIN / "tui.tsx").read_text(encoding="utf-8")
        achados = re.findall(r'import (?:type )?\{([^}]*)\} from "\./(\w+)\.ts"', cola)
        self.assertTrue(achados)
        for nomes, modulo in achados:
            existentes = self.exportados(modulo + ".ts")
            for nome in (n.strip() for n in nomes.split(",") if n.strip()):
                self.assertIn(nome, existentes, "tui.tsx importa %s de %s.ts, que não exporta" % (nome, modulo))

    def test_a_pasta_nao_tem_entrada_de_servidor(self):
        # O OpenCode procura `server.*`, `index.*` e `rpc.*` na pasta de cada plugin: aqui só há o TUI.
        nomes = {p.stem for p in PLUGIN.iterdir()}
        self.assertEqual(nomes & {"server", "index", "rpc"}, set())
        self.assertIn("tui", nomes)


if __name__ == "__main__":
    unittest.main()
