"""O que é do repo, e não da máquina: o `agents/hooks/check.sh` mede a instalação
(links, travas registradas, ferramentas), e estas duas conferências valem para o diff.

- Skill que cita outra (`Skill tool ... "grilling"`, `/grilling`) precisa que a citada
  exista no pacote.
- Os JSON que o repo declara (`mcp/`, `permissions/deny.json`, `settings/claude.json`,
  `travas/travas.json`) leem sem erro: o `agent_config` sai 2 quando o arquivo do repo
  é inválido. O arquivo do agente fica ausente (vale como vazio), então nada do $HOME
  real entra na conta."""

import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
PKG = Path(__file__).resolve().parents[1]
CONFIG = PKG / "hooks" / "agent_config.py"

# Caminhos de filesystem que aparecem entre crases não são skills.
NOT_SKILLS = {"tmp", "dev", "home", "usr", "etc", "var", "bin", "opt", "proc"}
CITATION = re.compile(r'Skill tool[^"]*"[a-z0-9-]+"|`/[a-z][a-z0-9-]+`')
NAME = re.compile(r'"[a-z0-9-]+"|/[a-z][a-z0-9-]+')


def citations(text):
    """Nomes de skill que o texto cita, linha a linha (a citação não cruza linhas)."""
    found = set()
    for line in text.splitlines():
        for citation in CITATION.findall(line):
            found.update(n.strip('"/') for n in NAME.findall(citation))
    return found - NOT_SKILLS


def broken_references(skills_dir):
    """[(skill, citada)] onde a citada não existe em `skills_dir`."""
    broken = []
    for md in sorted(Path(skills_dir).glob("*/SKILL.md")):
        skill = md.parent.name
        for ref in sorted(citations(md.read_text(encoding="utf-8")) - {skill}):
            if not (Path(skills_dir) / ref / "SKILL.md").is_file():
                broken.append((skill, ref))
    return broken


class Referencias(unittest.TestCase):
    def test_citacao_pela_ferramenta_e_pela_barra(self):
        text = 'Use a Skill tool with "grilling".\nOu rode `/domain-modeling` agora.\n'
        self.assertEqual(citations(text), {"grilling", "domain-modeling"})

    def test_caminho_de_filesystem_e_texto_sem_citacao_nao_contam(self):
        text = "Veja `/tmp` e /usr/bin/x; sem \"grilling\" fora da ferramenta.\n"
        self.assertEqual(citations(text), set())

    def test_citada_ausente_aparece_e_existente_nao(self):
        tmp = Path(tempfile.mkdtemp(prefix="refs-"))
        self.addCleanup(shutil.rmtree, tmp, ignore_errors=True)
        for name, body in {
            "aa": 'Skill tool with "bb" e `/cc` e `/aa`.\n',
            "bb": "sem citação\n",
        }.items():
            (tmp / name).mkdir()
            (tmp / name / "SKILL.md").write_text(body, encoding="utf-8")
        self.assertEqual(broken_references(tmp), [("aa", "cc")])

    def test_toda_skill_do_pacote_cita_so_skill_que_existe(self):
        self.assertEqual(broken_references(PKG / "skills"), [])


class JsonDoRepo(unittest.TestCase):
    """O arquivo do repo que o agent_config lê sai 0, contra um arquivo de agente ausente."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="repo-json-"))
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.absent = self.tmp / "agente.json"

    def run_cfg(self, *args):
        out = subprocess.run([sys.executable, "-I", str(CONFIG), *args], capture_output=True, text=True)
        self.assertEqual(out.returncode, 0, "%s: %s" % (" ".join(args[:2]), out.stderr))

    def test_mcp(self):
        self.run_cfg("mcp-servers", str(PKG / "mcp"))
        for agent in ("claude", "cursor"):
            self.run_cfg("mcp-plan", agent, str(self.absent), str(PKG / "mcp"))

    def test_deny(self):
        for agent in ("claude", "cursor"):
            self.run_cfg("deny-plan", agent, str(self.absent), str(PKG / "permissions" / "deny.json"))

    def test_settings_do_claude(self):
        self.run_cfg("settings-plan", "claude", str(self.absent), str(PKG / "settings" / "claude.json"))

    def test_travas(self):
        self.run_cfg("hooks-plan", "claude", str(self.absent), str(PKG / "travas" / "travas.json"))


if __name__ == "__main__":
    unittest.main()
