#!/usr/bin/env python3
"""Conta cards reais do repeater em arquivos Markdown e aponta armadilhas.

Imita as regras documentadas do repeater:
  - Q:/A:  -> 1 card
  - C:     -> 1 card por lacuna [..] não vazia
  - linha com '::' -> card de linha única
  - marcadores só valem na coluna 0; '---' na coluna 0 fecha o card

Uso:
  python count_cards.py ARQUIVO_OU_PASTA [...] [--budget 100] [--quiet]

A verificação definitiva continua sendo `repeater check --plain <pasta>`.
"""
import argparse
import re
import sys
from pathlib import Path

BLANK_RE = re.compile(r"\[([^\[\]]*)\]")


def strip_frontmatter(lines):
    if lines and lines[0].strip() == "---":
        for i in range(1, len(lines)):
            if lines[i].strip() == "---":
                return i + 1
    return 0


def analyze(path: Path):
    lines = path.read_text(encoding="utf-8").splitlines()
    start = strip_frontmatter(lines)
    stats = {"q": 0, "c_blocks": 0, "c_cards": 0, "single": 0}
    warnings = []
    card = None  # dict(kind, line, body[list], has_answer)
    in_fence = False
    has_section = any(l.strip() == "## Repeater Exercises" for l in lines)

    def flush(closed_by_separator):
        nonlocal card
        if card is None:
            return
        body = "\n".join(card["body"])
        ln = card["line"]
        if card["kind"] == "Q":
            if not card["has_answer"]:
                warnings.append(f"L{ln}: Q: sem A: (erro de parse)")
            else:
                stats["q"] += 1
        elif card["kind"] == "C":
            spans = BLANK_RE.findall(body)
            blanks = [s for s in spans if s.strip()]
            stats["c_blocks"] += 1
            stats["c_cards"] += len(blanks)
            if not blanks:
                warnings.append(f"L{ln}: C: sem lacunas (0 cards)")
            if len(blanks) >= 4:
                warnings.append(f"L{ln}: C: com {len(blanks)} lacunas — considere um Q:")
            if "[[" in body or re.search(r"\]\(", body):
                warnings.append(f"L{ln}: C: contém wikilink/link markdown — colchetes viram lacunas")
        for extra in card["body"][1:]:
            if re.match(r"#{1,6} ", extra):
                warnings.append(f"L{ln}: card engoliu um heading ('{extra[:40]}') — falta '---'?")
                break
        card = None

    for idx in range(start, len(lines)):
        raw = lines[idx]
        ln = idx + 1
        if raw.startswith("```"):
            in_fence = not in_fence

        if raw.rstrip() == "---":
            flush(True)
            continue
        if re.match(r"^\s+(Q:|A:|C:)", raw):
            warnings.append(f"L{ln}: marcador indentado é ignorado pelo repeater")
        if "::" in raw:
            flush(False)
            left, _, right = raw.partition("::")
            where = "em bloco de código" if in_fence else "fora de card" if card is None else "dentro de card"
            if left.strip() and right.strip():
                stats["single"] += 1
                warnings.append(f"L{ln}: linha com '::' ({where}) vira card de linha única: {raw.strip()[:60]}")
            else:
                warnings.append(f"L{ln}: linha com '::' ({where}) pode gerar card inválido: {raw.strip()[:60]}")
            continue
        if raw.startswith("Q:"):
            flush(False)
            card = {"kind": "Q", "line": ln, "body": [raw[2:]], "has_answer": False}
            continue
        if raw.startswith("C:"):
            flush(False)
            card = {"kind": "C", "line": ln, "body": [raw[2:]], "has_answer": True}
            continue
        if raw.startswith("A:"):
            if card and card["kind"] == "Q":
                card["has_answer"] = bool(raw[2:].strip()) or card["has_answer"]
                card["body"].append(raw[2:])
            else:
                warnings.append(f"L{ln}: A: sem Q: antes")
            continue
        if card is not None:
            card["body"].append(raw)
    if card is not None:
        ln = card["line"]
        flush(False)
        warnings.append(f"L{ln}: último card do arquivo sem '---' final")

    stats["total"] = stats["q"] + stats["c_cards"] + stats["single"]
    return stats, warnings, has_section


def collect(paths):
    files = []
    for p in paths:
        p = Path(p)
        if p.is_dir():
            files.extend(sorted(f for f in p.rglob("*.md")))
        elif p.suffix == ".md":
            files.append(p)
    return files


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--budget", type=int, default=None)
    ap.add_argument("--quiet", action="store_true", help="não listar avisos")
    args = ap.parse_args()

    files = collect(args.paths)
    if not files:
        print("Nenhum .md encontrado.", file=sys.stderr)
        return 1

    grand = 0
    print(f"{'arquivo':<55} {'Q':>3} {'C blk':>5} {'C cards':>7} {'::':>3} {'TOTAL':>5}")
    all_warnings = []
    for f in files:
        s, w, has_section = analyze(f)
        grand += s["total"]
        mark = "" if has_section or s["total"] == 0 else "  (sem '## Repeater Exercises')"
        print(f"{f.name[:55]:<55} {s['q']:>3} {s['c_blocks']:>5} {s['c_cards']:>7} {s['single']:>3} {s['total']:>5}{mark}")
        all_warnings.extend((f.name, x) for x in w)

    print(f"\nTOTAL de cards reais: {grand}")
    if args.budget is not None:
        diff = grand - args.budget
        status = "dentro do orçamento" if diff <= 0 else f"ACIMA do orçamento em {diff}"
        print(f"Orçamento: {args.budget} → {status}")

    if all_warnings and not args.quiet:
        print(f"\nAvisos ({len(all_warnings)}):")
        for name, w in all_warnings:
            print(f"  {name} {w}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
