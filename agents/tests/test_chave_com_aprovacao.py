"""Testes da trava `agents/travas/chave-com-aprovacao`: o uso de chave de API em ~/.config/claude/
pede aprovação (`ask`), e comando que não cita não gera saída.

O script não tem `.py`; roda de verdade, com o JSON do evento no stdin, como o Claude Code o chama."""

import json
import subprocess
import sys
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
PKG = Path(__file__).resolve().parents[1]
SCRIPT = PKG / "travas" / "chave-com-aprovacao"

TARGET = (
    "ssh pi01 'curl -s -H \"X-Emby-Token: $(cat ~/.config/claude/jellyfin-api-key)\" "
    "http://localhost:8096/System/Info'"
)


def run(event):
    done = subprocess.run([sys.executable, "-I", str(SCRIPT)], input=json.dumps(event), capture_output=True, text=True)
    assert done.returncode == 0, done.stderr
    return json.loads(done.stdout) if done.stdout.strip() else None


def bash(command):
    return {"tool_name": "Bash", "tool_input": {"command": command}, "cwd": "/tmp"}


class Trava(unittest.TestCase):
    def asks(self, command, *files):
        out = run(bash(command))
        self.assertIsNotNone(out, command)
        decision = out["hookSpecificOutput"]
        self.assertEqual(decision["hookEventName"], "PreToolUse")
        self.assertEqual(decision["permissionDecision"], "ask", command)
        self.assertIn("chave de API", decision["permissionDecisionReason"])
        for name in files:
            self.assertIn(name, decision["permissionDecisionReason"], command)

    def silent(self, command):
        self.assertIsNone(run(bash(command)), command)


class Pede(Trava):
    def test_o_caso_alvo_do_jellyfin_pelo_ssh(self):
        self.asks(TARGET, "~/.config/claude/jellyfin-api-key")

    def test_as_quatro_formas_de_citar_a_pasta(self):
        self.asks("cat ~/.config/claude/a-api-key", "~/.config/claude/a-api-key")
        self.asks("cat $HOME/.config/claude/a-api-key", "$HOME/.config/claude/a-api-key")
        self.asks("cat ${HOME}/.config/claude/a-api-key", "${HOME}/.config/claude/a-api-key")
        self.asks("cat /home/alguem/.config/claude/a-api-key", "/home/alguem/.config/claude/a-api-key")

    def test_a_pasta_sozinha_tambem_conta(self):
        self.asks("ls ~/.config/claude", "~/.config/claude")
        self.asks("ls -la ~/.config/claude/", "~/.config/claude/")

    def test_substituicao_de_comando_dentro_de_uma_palavra(self):
        self.asks('curl -H "X-Token: $(cat ~/.config/claude/k-api-key)" http://x', "k-api-key")
        self.asks("curl -H X-Token:$(cat ~/.config/claude/k-api-key) http://x", "k-api-key")
        self.asks("echo `cat $HOME/.config/claude/k-api-key`", "k-api-key")

    def test_bash_c_e_sh_c(self):
        self.asks("bash -c 'cat ~/.config/claude/k-api-key'", "k-api-key")
        self.asks("sh -c 'cat ~/.config/claude/k-api-key'", "k-api-key")
        self.asks("bash -lc 'cat ~/.config/claude/k-api-key'", "k-api-key")
        self.asks("sudo env X=1 bash -c 'cat ~/.config/claude/k-api-key'", "k-api-key")

    def test_aspas_de_dentro_que_o_shell_junta_so_depois_de_descer(self):
        # `"$HOME"/.config/claude/k` só vira `$HOME/.config/claude/k` quando o script de dentro é lido.
        self.asks("""bash -c 'cat "$HOME"/.config/claude/k-api-key'""", "$HOME/.config/claude/k-api-key")
        self.asks("""ssh pi01 'cat "$HOME"/.config/claude/k-api-key'""", "k-api-key")

    def test_ssh_com_opcoes_e_comando_em_varias_palavras(self):
        self.asks("ssh -p 22 -i ~/.ssh/k pi01 cat '$HOME/.config/claude/k-api-key'", "k-api-key")
        self.asks("""ssh -o BatchMode=yes pi01 cat '"$HOME"'/.config/claude/k-api-key""", "k-api-key")

    def test_shell_dentro_do_ssh(self):
        self.asks("""ssh pi01 "bash -c 'cat \\"\\$HOME\\"/.config/claude/k-api-key'" """, "k-api-key")

    def test_encadeado_com_outro_comando(self):
        self.asks("echo ok && cat ~/.config/claude/k-api-key | head -c 3", "k-api-key")
        self.asks("cd /tmp\ncat ~/.config/claude/k-api-key", "k-api-key")

    def test_aspas_sem_fechar_nao_escondem_a_citacao(self):
        # o shell recusaria o comando, mas a trava não decide pelo que o shell faria
        self.asks("cat ~/.config/claude/k-api-key \"abc", "k-api-key")
        self.asks("ssh pi01 'echo \"x; cat ~/.config/claude/k-api-key'", "k-api-key")

    def test_varios_arquivos_saem_no_motivo_sem_repetir(self):
        out = run(bash("cat ~/.config/claude/a-api-key ~/.config/claude/b-api-key ~/.config/claude/a-api-key"))
        reason = out["hookSpecificOutput"]["permissionDecisionReason"]
        self.assertEqual(reason.count("a-api-key"), 1)
        self.assertIn("b-api-key", reason)


class NaoPede(Trava):
    def test_comando_que_nao_cita(self):
        self.silent("ls -la")
        self.silent("ssh pi01 uptime")
        self.silent("curl -s http://localhost:8096/System/Info")
        self.silent("bash -c 'echo oi'")
        self.silent("cat ~/.claude/settings.json")
        self.silent("cat ~/.config/gh/hosts.yml")

    def test_pasta_de_nome_parecido(self):
        self.silent("cat ~/.config/claude-code/x")
        self.silent("cat ~/.config/claudex/x")
        self.silent("cat ~/.config/claude.bak")
        self.silent("cat /etc/.config/claude/x")
        self.silent("cat ~/dev/.config/claude/x")

    def test_aspas_sem_fechar_sem_citacao(self):
        self.silent("echo \"abc")
        self.silent("ssh pi01 'echo \"x'")

    def test_outra_ferramenta_ou_entrada_torta(self):
        self.assertIsNone(run({"tool_name": "Read", "tool_input": {"file_path": "~/.config/claude/k"}}))
        self.assertIsNone(run({"tool_name": "Bash", "tool_input": {}}))
        self.assertIsNone(run({"tool_name": "Bash", "tool_input": "cat ~/.config/claude/k"}))
        self.assertIsNone(run({"tool_name": "Bash"}))
        for stdin in ("", "{ nao", "[1]", "null"):
            done = subprocess.run([sys.executable, "-I", str(SCRIPT)], input=stdin, capture_output=True, text=True)
            self.assertEqual((done.returncode, done.stdout), (0, ""), stdin)


class Registro(unittest.TestCase):
    def test_travas_json_registra_a_trava_no_bash_do_pre_tool_use(self):
        spec = json.loads((PKG / "travas" / "travas.json").read_text())
        groups = [g for g in spec["PreToolUse"] if any("chave-com-aprovacao" in h["command"] for h in g["hooks"])]
        self.assertEqual([g["matcher"] for g in groups], ["Bash"])
        self.assertTrue(SCRIPT.stat().st_mode & 0o111)


if __name__ == "__main__":
    unittest.main()
