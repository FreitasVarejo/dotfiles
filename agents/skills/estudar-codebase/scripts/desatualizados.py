#!/usr/bin/env python3
"""Diz, por capítulo, se o mapa de uma codebase envelheceu (skill `estudar-codebase`).

  desatualizados.py <pasta-do-estudo>

Sem LLM e só com a biblioteca padrão: roda `git` na codebase que a linha
`- **Codebase:**` do README.md da pasta aponta. Para cada `mapa/NN-<slug>.md`:

  - lê o `sha:` do frontmatter (o commit que o capítulo leu) e as âncoras
    `` `caminho/arquivo#Símbolo` `` do texto (a linha `(L120@abc1234)` depois
    delas é só dica e não entra na conta; método se escreve `Classe.metodo`);
  - `git grep -w` no HEAD acha a âncora quebrada: o arquivo sumiu, ou o símbolo
    (cada parte de `Classe.metodo`) não aparece mais nele;
  - `git diff <sha>..HEAD` nos arquivos das âncoras acha a tocada: o último
    nome do símbolo aparece numa linha mudada ou no cabeçalho do hunk. Para o
    cabeçalho dizer o método e não só a última linha sem indentação, o git
    ganha os drivers de função das linguagens que ele conhece (`.gitattributes`
    do repo, se houver, vale mais). JavaScript e TypeScript não têm driver no
    git: ali o cabeçalho continua sendo a última linha sem indentação, e uma
    mudança dentro de um método que não cita o nome dele na linha mudada sai
    `em dia`. Num repo assim, `em dia` não prova que o símbolo ficou igual.

Uma linha por capítulo, com um estado só: `em dia`, `tocado: <âncoras>` ou
`quebrada: <âncoras e motivo>`. Quebrada vence tocada. Capítulo sem `sha:`, com
sha que o repo não conhece ou sem âncora também sai `quebrada`, com o motivo:
nada ali se pode conferir.

Sai 0 sempre que conseguiu olhar, qualquer que seja o estado dos capítulos; sai
2 quando não sabe qual é a codebase (README sem a linha, repo ilegível).
"""
import argparse
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

CODEBASE_RE = re.compile(r"^- \*\*Codebase:\*\*[ \t]*(.+?)[ \t]*$", re.M)
ANCHOR_RE = re.compile(r"`([^`\s#]+)#([^`\s]+)`")
SHA_RE = re.compile(r"^[0-9a-fA-F]{4,40}$")
HUNK_RE = re.compile(r"^@@ -\d+(?:,\d+)? \+\d+(?:,\d+)? @@ ?(.*)$")
DIFF_RE = re.compile(r"^diff --git a/(.+) b/(.+)$")
CHAPTER_RE = re.compile(r"^\d\d-.+\.md$")

# Drivers de função embutidos no git, por extensão. Sem eles, o cabeçalho do
# hunk é a última linha sem indentação, que num método é só a classe.
DIFF_DRIVERS = {
    "cs": "csharp", "py": "python", "java": "java", "go": "golang", "rs": "rust",
    "rb": "ruby", "php": "php", "kt": "kotlin", "kts": "kotlin", "ex": "elixir",
    "exs": "elixir", "sh": "bash",
}


def parse_frontmatter(text):
    lines = text.splitlines()
    fields = {}
    if lines and lines[0].strip() == "---":
        for line in lines[1:]:
            if line.strip() == "---":
                break
            m = re.match(r"^(\w+):[ \t]*(.*?)[ \t]*$", line)
            if m:
                fields[m.group(1)] = m.group(2).strip("\"'")
    return fields


def parse_anchors(text):
    """[(arquivo, símbolo)] na ordem do texto, sem repetir. `url#fragmento` não é âncora."""
    seen = []
    for path, symbol in ANCHOR_RE.findall(text):
        if "://" in path:
            continue
        if symbol.endswith("()"):
            symbol = symbol[:-2]
        if symbol and (path, symbol) not in seen:
            seen.append((path, symbol))
    return seen


def codebase_path(readme_text):
    m = CODEBASE_RE.search(readme_text)
    return os.path.expanduser(m.group(1).strip("`")) if m else None


def symbol_parts(symbol):
    return [p for p in symbol.split(".") if p]


class Repo:
    def __init__(self, root, attributes_file):
        self.root = root
        self.attributes_file = attributes_file

    def git(self, *args):
        cmd = ["git", "--literal-pathspecs", "-c", "core.quotepath=off",
               "-c", f"core.attributesFile={self.attributes_file}", "-C", self.root, *args]
        return subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")

    def rev(self, name):
        r = self.git("rev-parse", "--verify", "--quiet", f"{name}^{{commit}}")
        return r.stdout.strip() if r.returncode == 0 else None

    def broken(self, path, symbol):
        """Por que a âncora não se acha no HEAD, ou None se ela se acha."""
        if self.git("cat-file", "-e", f"HEAD:{path}").returncode != 0:
            return "arquivo não existe no HEAD"
        for part in symbol_parts(symbol):
            if self.git("grep", "-q", "-w", "-F", "-e", part, "HEAD", "--", path).returncode != 0:
                return f"`{part}` não aparece em {path} no HEAD"
        return None

    def hunks(self, sha, paths):
        """{arquivo: [texto de cada hunk: cabeçalho + linhas mudadas]} de sha..HEAD."""
        out = self.git("diff", "--no-color", "--no-ext-diff", "--no-renames", "-U0",
                       f"{sha}..HEAD", "--", *paths).stdout
        by_file, current, in_hunk = {}, None, False
        for line in out.splitlines():
            m = DIFF_RE.match(line)
            if m:
                current, in_hunk = m.group(2), False
                by_file.setdefault(current, [])
                continue
            m = HUNK_RE.match(line)
            if m and current is not None:
                in_hunk = True
                by_file[current].append([m.group(1)])
            elif in_hunk and line[:1] in ("+", "-"):
                by_file[current][-1].append(line[1:])
        return {f: ["\n".join(h) for h in hs] for f, hs in by_file.items()}


def touched(symbol, hunks):
    leaf = symbol_parts(symbol)[-1]
    word = re.compile(r"(?<![\w$])" + re.escape(leaf) + r"(?![\w$])")
    return any(word.search(h) for h in hunks)


def check_chapter(repo, head, text):
    """(estado, detalhe) de um capítulo: `em dia`, `tocado` ou `quebrada`."""
    sha = parse_frontmatter(text).get("sha", "")
    anchors = parse_anchors(text)
    if not sha or not SHA_RE.match(sha):
        return "quebrada", "sem `sha:` no frontmatter"
    if not anchors:
        return "quebrada", "sem âncora `arquivo#Símbolo`"
    full = repo.rev(sha)
    if full is None:
        return "quebrada", f"o sha {sha} não existe neste repo"

    broken = [f"{p}#{s} ({why})" for p, s in anchors if (why := repo.broken(p, s))]
    if broken:
        return "quebrada", "; ".join(broken)
    if full == head:
        return "em dia", ""
    by_file = repo.hunks(sha, sorted({p for p, _ in anchors}))
    hit = [f"{p}#{s}" for p, s in anchors if touched(s, by_file.get(p, []))]
    return ("tocado", ", ".join(hit)) if hit else ("em dia", "")


def attributes_text():
    return "".join(f"*.{ext} diff={driver}\n" for ext, driver in DIFF_DRIVERS.items())


def main(argv=None):
    ap = argparse.ArgumentParser(
        prog="desatualizados.py", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("pasta", help="pasta do estudo (a que tem README.md com a linha `- **Codebase:**`)")
    args = ap.parse_args(argv)

    study = Path(args.pasta).expanduser()
    readme = study / "README.md"
    if not readme.is_file():
        print(f"sem README.md em {study}", file=sys.stderr)
        return 2
    codebase = codebase_path(readme.read_text(encoding="utf-8"))
    if not codebase:
        print(f"{readme} não tem a linha `- **Codebase:** <caminho>`", file=sys.stderr)
        return 2

    with tempfile.TemporaryDirectory() as tmp:
        attributes = Path(tmp) / "attributes"
        attributes.write_text(attributes_text(), encoding="utf-8")
        probe = Repo(codebase, attributes)
        top = probe.git("rev-parse", "--show-toplevel")
        if top.returncode != 0:
            print(f"{codebase} não é um repo git", file=sys.stderr)
            return 2
        repo = Repo(top.stdout.strip(), attributes)
        head = repo.rev("HEAD")
        if head is None:
            print(f"{repo.root} não tem HEAD", file=sys.stderr)
            return 2

        print(f"codebase {repo.root} em {head[:7]}")
        chapters = sorted(p for p in (study / "mapa").glob("*.md") if CHAPTER_RE.match(p.name) and p.name != "00-index.md")
        if not chapters:
            print("nenhum capítulo em mapa/")
        for path in chapters:
            text = path.read_text(encoding="utf-8")
            sha = parse_frontmatter(text).get("sha", "")
            state, detail = check_chapter(repo, head, text)
            label = f"{state}: {detail}" if detail else state
            print(f"{path.name} (sha {sha[:7] or '-'}) — {label}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
