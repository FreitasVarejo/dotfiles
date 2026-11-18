"""O plugin `contexto` do OpenCode (agents/opencode/plugins/contexto/): regras com `paths:`, memória e
CLAUDE.md com `@imports`.

O OpenCode só carrega o plugin de verdade na partida dele; aqui a lógica (`contexto.ts`) e os ganchos
(`server.ts`, com um `ctx` falso) rodam no Node, que apaga os tipos do TypeScript. Cada teste monta um
HOME e um projeto temporários: nada do $HOME real entra na conta."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
PLUGIN = Path(__file__).resolve().parents[1] / "opencode" / "plugins" / "contexto"
NODE = shutil.which("node")
KEY = r"^[a-z0-9][a-z0-9._-]*$"


@unittest.skipUnless(NODE, "node não encontrado: o plugin só se testa com ele")
class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="oc-contexto-")).resolve()
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.home = self.tmp / "home"
        self.home.mkdir()

    def write(self, rel, text=""):
        path = self.home / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(textwrap.dedent(text).lstrip("\n"), encoding="utf-8")
        return path

    def js(self, body, module="contexto.ts"):
        """Roda `body` (módulo ESM) com `m` = o módulo do plugin e `home`; o que ele imprime é JSON."""
        script = 'import * as m from "%s"\nconst home = %s\n%s' % (
            (PLUGIN / module).as_uri(),
            json.dumps(str(self.home)),
            body,
        )
        env = dict(os.environ, HOME=str(self.home))
        done = subprocess.run(
            [NODE, "--no-warnings", "--input-type=module", "-e", script],
            capture_output=True, text=True, env=env, timeout=60,
        )
        self.assertEqual(done.returncode, 0, done.stderr)
        return json.loads(done.stdout)


class Globs(Base):
    def matches(self, glob, path):
        return self.js("console.log(JSON.stringify(m.globToRegExp(%s).test(%s)))" % (json.dumps(glob), json.dumps(path)))

    def test_glob_no_estilo_do_paths(self):
        casos = [
            ("**/*.sh", "setup.sh", True),
            ("**/*.sh", "a/b/c.sh", True),
            ("**/*.sh", "a/b/c.lua", False),
            ("bash/**", "bash/.bashrc.d/x.sh", True),
            ("bash/**", "nvim/bash/x", False),
            ("nvim/**", "nvim/lua/a.lua", True),
            ("*.md", "README.md", True),
            ("*.md", "docs/README.md", False),
            ("src/*.{ts,tsx}", "src/a.tsx", True),
            ("src/*.{ts,tsx}", "src/a.js", False),
            ("a?c.txt", "abc.txt", True),
            ("nvim/lua/plugins/lang/dotnet.lua", "nvim/lua/plugins/lang/dotnet.lua", True),
            ("nvim/lua/plugins/lang/dotnet.lua", "nvim/lua/plugins/lang/dotnetXlua", False),
            ("./docs/", "docs/a/b.md", True),
        ]
        for glob, path, esperado in casos:
            with self.subTest(glob=glob, path=path):
                self.assertEqual(self.matches(glob, path), esperado)


class Regras(Base):
    def project(self):
        self.write("proj/.git/HEAD", "ref: refs/heads/main")
        self.write("proj/.claude/rules/bash.md", """
            ---
            paths:
              - "bash/**"
              - "**/*.sh"
            ---

            # Shell

            Use `[[ ]]`.
            """)
        self.write("proj/.claude/rules/nvim.md", """
            ---
            paths: ["nvim/**"]
            ---
            Lua com 2 espaços.
            """)
        self.write("proj/.claude/rules/sempre.md", "Sem paths: o Claude Code carrega na partida, aqui não.\n")
        return self.home / "proj"

    def entries(self, touched):
        proj = self.project()
        return self.js(
            "const p = m.findProject(%s)\nconsole.log(JSON.stringify(m.rulesFor(p, p.root, %s)))"
            % (json.dumps(str(proj)), json.dumps(touched))
        )

    def test_sh_traz_a_regra_do_bash_e_lua_nao(self):
        sh = self.entries(["scripts/x.sh"])
        self.assertEqual([e["key"] for e in sh], ["regra-bash"])
        self.assertIn("Use `[[ ]]`.", sh[0]["value"])
        self.assertNotIn("paths:", sh[0]["value"])
        self.assertEqual(self.entries(["nvim/lua/a.lua"])[0]["key"], "regra-nvim")
        self.assertEqual(self.entries(["docs/a.md"]), [])

    def test_regra_sem_paths_fica_de_fora(self):
        keys = [e["key"] for e in self.entries(["bash/x", "nvim/y"])]
        self.assertEqual(sorted(keys), ["regra-bash", "regra-nvim"])

    def test_caminho_absoluto_de_fora_do_projeto_nao_casa(self):
        self.assertEqual(self.entries([str(self.home / "outro" / "x.sh")]), [])

    def test_a_chave_obedece_o_padrao_do_opencode(self):
        for e in self.entries(["bash/x", "nvim/y"]):
            self.assertRegex(e["key"], KEY)

    def test_parse_de_paths_em_lista_corrida_e_inline(self):
        out = self.js(
            textwrap.dedent(
                r"""
                const t = (s) => m.parseRule("f", "n.md", s)?.paths ?? null
                console.log(JSON.stringify([
                  t("---\npaths: a/**, b/*.{x,y}\n---\ncorpo"),
                  t("---\npaths: [\"a\", 'b']\n---\ncorpo"),
                  t("---\ndescription: x\n---\ncorpo"),
                  t("sem frontmatter"),
                ]))
                """
            )
        )
        self.assertEqual(out, [["a/**", "b/*.{x,y}"], ["a", "b"], None, None])

    def test_arquivos_tocados_por_ferramenta(self):
        out = self.js(
            textwrap.dedent(
                r"""
                const patch = "*** Begin Patch\n*** Add File: a/novo.sh\n+x\n*** Update File: b.lua\n*** Move to: c.lua\n*** Delete File: d.md\n*** End Patch"
                console.log(JSON.stringify([
                  m.touchedPaths("read", { path: "x.sh" }),
                  m.touchedPaths("edit", { path: "y.sh", oldString: "a" }),
                  m.touchedPaths("write", { path: "z.sh" }),
                  m.touchedPaths("patch", { patchText: patch }),
                  m.touchedPaths("shell", { command: "cat x.sh" }),
                  m.touchedPaths("read", null),
                ]))
                """
            )
        )
        self.assertEqual(out, [["x.sh"], ["y.sh"], ["z.sh"], ["a/novo.sh", "b.lua", "c.lua", "d.md"], [], []])


class Projeto(Base):
    def test_worktree_usa_a_memoria_do_repo_principal(self):
        self.write("main/.git/HEAD", "x")
        self.write("main/.git/worktrees/wt/gitdir", "x")
        self.write("wt/.git", "gitdir: %s\n" % (self.home / "main/.git/worktrees/wt"))
        out = self.js(
            "console.log(JSON.stringify([m.findProject(%s), m.findProject(%s)]))"
            % (json.dumps(str(self.home / "wt" / "src")), json.dumps(str(self.home / "main")))
        )
        self.assertEqual(out[0], {"root": str(self.home / "wt"), "canonical": str(self.home / "main")})
        self.assertEqual(out[1], {"root": str(self.home / "main"), "canonical": str(self.home / "main")})

    def test_sem_git_o_projeto_e_a_pasta(self):
        (self.home / "solta").mkdir()
        out = self.js("console.log(JSON.stringify(m.findProject(%s)))" % json.dumps(str(self.home / "solta")))
        self.assertEqual(out, {"root": str(self.home / "solta"), "canonical": str(self.home / "solta")})

    def test_slug_igual_ao_do_claude_code(self):
        out = self.js(
            'console.log(JSON.stringify(["/home/u/dotfiles", "/home/u/dev/bjju-vision/.claude/worktrees/a_b", "/home/u/ç"].map(m.projectSlug)))'
        )
        self.assertEqual(
            out, ["-home-u-dotfiles", "-home-u-dev-bjju-vision--claude-worktrees-a-b", "-home-u--"]
        )


class Memoria(Base):
    def entry(self, dirname="mem"):
        return self.js(
            "console.log(JSON.stringify(m.memoryEntry(%s, home)))" % json.dumps(str(self.home / dirname))
        )

    def test_sem_memoria_a_entrada_existe_e_diz_o_diretorio(self):
        e = self.entry()
        self.assertEqual(e["key"], "memoria")
        self.assertIn("~/mem", e["value"])
        self.assertIn("ainda não há memória", e["value"])

    def test_traz_o_indice(self):
        self.write("mem/MEMORY.md", "- [Fato](fato.md) — um fato\n")
        self.assertIn("- [Fato](fato.md) — um fato", self.entry()["value"])

    def test_indice_longo_e_cortado_em_200_linhas(self):
        self.write("mem/MEMORY.md", "\n".join("- linha %d" % i for i in range(300)))
        value = self.entry()["value"]
        self.assertIn("- linha 199", value)
        self.assertNotIn("- linha 200", value)
        self.assertIn("cortado", value)

    def test_caminho_da_memoria_pelo_slug_do_repo_principal(self):
        out = self.js(
            "console.log(JSON.stringify(m.memoryDir(home, { root: '/x/wt', canonical: '/x/main' })))"
        )
        self.assertEqual(out, str(self.home / ".claude/projects/-x-main/memory"))


class ClaudeMd(Base):
    def entries(self, cwd):
        return self.js("console.log(JSON.stringify(m.claudeMdEntries(%s, home)))" % json.dumps(str(self.home / cwd)))

    def test_imports_resolvidos_relativos_ao_arquivo_que_importa(self):
        self.write("proj/CLAUDE.md", "# Topo\n\nVeja @docs/a.md e @~/global.md.\n\nEmail a@b.com não é import.\n")
        self.write("proj/docs/a.md", "Texto A, que importa @b.md\n")
        self.write("proj/docs/b.md", "Texto B\n")
        self.write("global.md", "Texto global\n")
        (entry,) = self.entries("proj")
        self.assertEqual(entry["key"], "claude-md-proj")
        for trecho in ("# Topo", "Texto A", "Texto B", "Texto global"):
            self.assertIn(trecho, entry["value"])
        self.assertLess(entry["value"].index("Texto A"), entry["value"].index("Texto B"))
        self.assertIn("(imported from %s)" % (self.home / "proj/docs/a.md"), entry["value"])

    def test_import_em_codigo_nao_conta(self):
        self.write("proj/CLAUDE.md", "Use `@docs/a.md` assim.\n\n```\n@docs/a.md\n```\n")
        self.write("proj/docs/a.md", "SEGREDO\n")
        (entry,) = self.entries("proj")
        self.assertNotIn("SEGREDO", entry["value"])

    def test_import_que_sai_da_home_e_ignorado_com_aviso(self):
        outside = self.tmp / "fora.md"
        outside.write_text("CONTEUDO DE FORA\n")
        self.write("proj/CLAUDE.md", "Veja @../../fora.md e @../../nao-existe.md, @angular/core e @alguem\n")
        (entry,) = self.entries("proj")
        self.assertNotIn("CONTEUDO DE FORA", entry["value"])
        self.assertIn("import ignorado, fora da home: @../../fora.md", entry["value"])
        self.assertIn("import ignorado, fora da home: @../../nao-existe.md", entry["value"])
        self.assertEqual(entry["value"].count("import ignorado"), 2)

    def test_cadeia_de_ate_5_niveis(self):
        for n in range(0, 8):
            self.write("proj/n%d.md" % n, "NIVEL%d @n%d.md\n" % (n, n + 1))
        self.write("proj/CLAUDE.md", "RAIZ @n0.md\n")
        (entry,) = self.entries("proj")
        # CLAUDE.md é o nível 0; n0..n4 são os níveis 1 a 5; n5 passa do limite
        self.assertIn("NIVEL4", entry["value"])
        self.assertNotIn("NIVEL5 ", entry["value"])
        self.assertIn("passa de 5 níveis: @n5.md", entry["value"])

    def test_ciclo_nao_repete_nem_trava(self):
        self.write("proj/CLAUDE.md", "A @b.md\n")
        self.write("proj/b.md", "B @CLAUDE.md\n")
        (entry,) = self.entries("proj")
        self.assertEqual(entry["value"].count("Contents of"), 2)

    def test_claude_md_so_com_o_import_do_agents_md_fica_de_fora(self):
        self.write("proj/CLAUDE.md", "@AGENTS.md\n")
        self.write("proj/AGENTS.md", "regras\n")
        self.assertEqual(self.entries("proj"), [])

    def test_claude_md_com_agents_md_ao_lado_entra_so_com_a_secao_propria(self):
        self.write("proj/CLAUDE.md", "@AGENTS.md\n\n## Portões e métricas\n\nSECAO PROPRIA\n")
        self.write("proj/AGENTS.md", "REGRAS DO AGENTS\n")
        (entry,) = self.entries("proj")
        self.assertIn("SECAO PROPRIA", entry["value"])
        self.assertNotIn("REGRAS DO AGENTS", entry["value"])
        self.assertEqual(entry["value"].count("Contents of"), 1)

    def test_import_de_agents_md_que_o_opencode_nao_le_continua_expandido(self):
        self.write("proj/CLAUDE.md", "@AGENTS.md\n@docs/AGENTS.md\n\nPROPRIO\n")
        self.write("proj/AGENTS.md", "NATIVO\n")
        self.write("proj/docs/AGENTS.md", "NAO LIDO\n")
        (entry,) = self.entries("proj")
        self.assertIn("PROPRIO", entry["value"])
        self.assertIn("NAO LIDO", entry["value"])
        self.assertNotIn("NATIVO", entry["value"])

    def test_import_do_agents_md_de_uma_pasta_acima_na_cadeia_tambem_e_pulado(self):
        self.write("AGENTS.md", "DA HOME\n")
        self.write("a/b/CLAUDE.md", "@../../AGENTS.md\n\nPROPRIO\n")
        (entry,) = self.entries("a/b")
        self.assertIn("PROPRIO", entry["value"])
        self.assertNotIn("DA HOME", entry["value"])

    def test_agents_md_fora_da_cadeia_da_sessao_nao_e_nativo(self):
        self.write("proj/CLAUDE.md", "@../outro/AGENTS.md\n\nPROPRIO\n")
        self.write("outro/AGENTS.md", "DE OUTRA PASTA\n")
        (entry,) = self.entries("proj")
        self.assertIn("DE OUTRA PASTA", entry["value"])

    def test_da_home_ate_a_pasta_da_sessao_o_mais_geral_primeiro(self):
        self.write("CLAUDE.md", "HOME\n")
        self.write("a/CLAUDE.md", "A\n")
        self.write("a/b/c/CLAUDE.md", "C\n")
        self.write("a/b/AGENTS.md", "x\n")
        self.write("a/b/CLAUDE.md", "B\n")
        keys = [e["key"] for e in self.entries("a/b/c")]
        self.assertEqual(keys, ["claude-md-home", "claude-md-a", "claude-md-a-b", "claude-md-a-b-c"])
        for key in keys:
            self.assertRegex(key, KEY)


class Ganchos(Base):
    """`server.ts` com um `ctx` falso: o que cada gancho põe, e quando."""

    HARNESS = textwrap.dedent(
        r"""
        import plugin from %(server)s
        const puts = []
        const hooks = {}
        const ctx = {
          session: {
            get: async ({ sessionID }) => ({ location: { directory: %(cwd)s } }),
            hook: async (name, fn) => { hooks["session." + name] = fn },
            instructions: { entry: { put: async (x) => { puts.push(x) } } },
          },
          tool: { hook: async (name, fn) => { hooks["tool." + name] = fn } },
        }
        await plugin.setup(ctx)
        %(body)s
        console.log(JSON.stringify(puts.map((p) => ({ session: p.sessionID, key: p.key }))))
        """
    )

    def run_plugin(self, cwd, body):
        script = self.HARNESS % {
            "server": json.dumps((PLUGIN / "server.ts").as_uri()),
            "cwd": json.dumps(str(cwd)),
            "body": body,
        }
        env = dict(os.environ, HOME=str(self.home))
        done = subprocess.run(
            [NODE, "--no-warnings", "--input-type=module", "-e", script],
            capture_output=True, text=True, env=env, timeout=60,
        )
        self.assertEqual(done.returncode, 0, done.stderr)
        return json.loads(done.stdout)

    def setUp(self):
        super().setUp()
        self.write("proj/.git/HEAD", "x")
        self.write("proj/CLAUDE.md", "contexto do projeto\n")
        self.write("proj/.claude/rules/bash.md", "---\npaths:\n  - '**/*.sh'\n---\nregra bash\n")
        self.write("proj/x.sh", "#!/bin/bash\n")
        self.write("proj/y.lua", "")

    def test_a_partida_poe_memoria_e_claude_md_uma_vez_por_sessao(self):
        puts = self.run_plugin(
            self.home / "proj",
            'await hooks["session.prompt"]({ sessionID: "s1" })\nawait hooks["session.prompt"]({ sessionID: "s1" })',
        )
        self.assertEqual(puts, [{"session": "s1", "key": "memoria"}, {"session": "s1", "key": "claude-md-proj"}])

    def test_ferramenta_de_arquivo_poe_a_regra_uma_vez(self):
        done = {"status": "completed", "sessionID": "s1"}
        puts = self.run_plugin(
            self.home / "proj",
            """
            await hooks["tool.execute.after"]({ ...%s, tool: "read", input: { path: "y.lua" } })
            await hooks["tool.execute.after"]({ ...%s, tool: "edit", input: { path: "x.sh" } })
            await hooks["tool.execute.after"]({ ...%s, tool: "write", input: { path: "x.sh" } })
            await hooks["tool.execute.after"]({ ...%s, tool: "shell", input: { command: "cat x.sh" } })
            """
            % ((json.dumps(done),) * 4),
        )
        self.assertEqual(puts, [{"session": "s1", "key": "regra-bash"}])

    def test_ferramenta_que_falhou_nao_traz_regra(self):
        puts = self.run_plugin(
            self.home / "proj",
            'await hooks["tool.execute.after"]({ status: "error", sessionID: "s1", tool: "read", input: { path: "x.sh" } })',
        )
        self.assertEqual(puts, [])

    def test_sessao_que_nao_se_acha_nao_derruba_o_gancho(self):
        puts = self.run_plugin(
            self.home / "proj",
            "ctx.session.get = async () => { throw new Error('sumiu') }\n"
            'await hooks["session.prompt"]({ sessionID: "s2" })',
        )
        self.assertEqual(puts, [])


class Instrucoes(unittest.TestCase):
    """As regras de escrita da memória, que no Claude Code vêm do prompt dele, moram no arquivo só do OpenCode."""

    def test_o_arquivo_so_do_opencode_ensina_a_gravar_memoria(self):
        text = (PLUGIN.parents[1] / "instructions.md").read_text(encoding="utf-8")
        for needle in ("~/.claude/projects/<slug>/memory/", 'key="memoria"', "MEMORY.md", "name:", "description:",
                       "type: feedback", "200 linhas", "Um fato por arquivo", "feedback", "user", "project", "reference"):
            self.assertIn(needle, text, needle)

    def test_o_que_a_entrada_diz_bate_com_as_instrucoes(self):
        # a entrada manda "as instruções de memória" e o texto delas está sob este título
        text = (PLUGIN.parents[1] / "instructions.md").read_text(encoding="utf-8")
        self.assertIn("## Memória do projeto", text)
        self.assertIn("as instruções de memória", (PLUGIN / "contexto.ts").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
