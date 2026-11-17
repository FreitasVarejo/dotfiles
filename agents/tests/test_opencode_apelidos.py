"""O plugin de apelidos do OpenCode e a cola `/atalhos`: todo apelido do plugin consta na cola.

Não carrega o plugin (isso só o OpenCode faz): lê o tui.tsx como texto."""

import re
import sys
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
OPENCODE = Path(__file__).resolve().parents[1] / "opencode"


class Apelidos(unittest.TestCase):
    def test_todo_apelido_do_plugin_esta_na_cola_atalhos(self):
        plugin = (OPENCODE / "plugins" / "apelidos" / "tui.tsx").read_text(encoding="utf-8")
        cola = (OPENCODE / "commands" / "atalhos.md").read_text(encoding="utf-8")
        slashes = re.findall(r'\{ slash: "([a-z-]+)"', plugin)
        self.assertTrue(slashes, "nenhum apelido lido do tui.tsx")
        for slash in slashes:
            self.assertIn("`/%s`" % slash, cola, "/atalhos não cita /%s" % slash)

    def test_cada_apelido_despacha_um_id_nativo_nao_vazio(self):
        plugin = (OPENCODE / "plugins" / "apelidos" / "tui.tsx").read_text(encoding="utf-8")
        for slash, native in re.findall(r'\{ slash: "([a-z-]+)", id: "([^"]*)"', plugin):
            self.assertRegex(native, r"^[a-z]+(\.[a-z_]+)+$", slash)


if __name__ == "__main__":
    unittest.main()
