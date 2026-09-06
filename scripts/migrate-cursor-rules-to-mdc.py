#!/usr/bin/env python3
"""Split .cursor-rules.md into .cursor/rules/*.mdc with Cursor frontmatter."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / ".cursor-rules.md"
RULES_DIR = ROOT / ".cursor/rules"

# Section title (after ##) -> output filename + alwaysApply
SECTION_MAP: list[tuple[str, str, bool]] = [
    ("Indice delle regole", "00-indice.mdc", True),
    (
        "NON Modificare Senza Conferma - Analisi sì, scrittura solo con ok esplicito",
        "01-conferma-scrittura.mdc",
        True,
    ),
    ("Spec-Driven Development (SDD) — registro delle promesse", "02-sdd.mdc", True),
    (
        "Modello (DDD + UML + Statechart) — rappresentazione dell'applicazione",
        "03-modello.mdc",
        True,
    ),
    (
        "Mappa del Progetto - Genera/aggiorna mappa completa PRIMA di ogni task",
        "04-project-map.mdc",
        True,
    ),
    (
        "Documentazione - Scrivere SOLO per me stesso, MAI per l'utente",
        "05-documentazione.mdc",
        True,
    ),
    (
        "Metodo Analitico - Approfondire e comprendere il problema",
        "06-metodo-analitico.mdc",
        True,
    ),
    (
        "Analisi Architetturale - Cercare errori di design prima di tutto",
        "07-analisi-architetturale.mdc",
        True,
    ),
    (
        "DRY, KISS e Unificazioni - Semplificare quando c'è occasione",
        "08-dry-kiss-unificazioni.mdc",
        True,
    ),
    (
        "Principio di Certezza - Agire solo con comprensione chiara",
        "09-principio-certezza.mdc",
        True,
    ),
    (
        "Revisione completa del codice - PRIMA di modificare",
        "10-revisione-codice.mdc",
        True,
    ),
    ("Debug e Testing - NON chiedere all'utente", "11-debug-testing.mdc", True),
    ("Build - SEMPRE dopo modifiche", "12-build.mdc", True),
    (
        "Dettaglio del Codice - L'utente si fida completamente",
        "13-dettaglio-codice.mdc",
        True,
    ),
    ("Riepilogo: Workflow completo", "14-workflow-riepilogo.mdc", True),
]

HEADER_RE = re.compile(r"^## (.+)$", re.MULTILINE)


def split_sections(text: str) -> dict[str, str]:
    matches = list(HEADER_RE.finditer(text))
    sections: dict[str, str] = {}

    # Preamble before first ## (title line)
    if matches:
        preamble = text[: matches[0].start()].strip()
        if preamble:
            sections["__preamble__"] = preamble

    for i, match in enumerate(matches):
        title = match.group(1).strip()
        start = match.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        body = text[start:end].strip()
        sections[title] = body

    return sections


def short_description(title: str) -> str:
    return f"Regole Alfred: {title}"


def write_mdc(path: Path, title: str, body: str, always_apply: bool) -> None:
    frontmatter = (
        "---\n"
        f"description: {short_description(title)!r}\n"
        f"alwaysApply: {'true' if always_apply else 'false'}\n"
        "---\n\n"
    )
    path.write_text(frontmatter + body + "\n", encoding="utf-8")


def main() -> None:
    source_text = SOURCE.read_text(encoding="utf-8")
    sections = split_sections(source_text)

    RULES_DIR.mkdir(parents=True, exist_ok=True)

    # Remove legacy main.mdc (superseded by numbered rules)
    legacy = RULES_DIR / "main.mdc"
    if legacy.exists():
        legacy.unlink()

    preamble = sections.pop("__preamble__", "")

    written: list[str] = []
    for title, filename, always_apply in SECTION_MAP:
        if title not in sections:
            raise SystemExit(f"Missing section in source: {title}")
        body = sections[title]
        if filename == "00-indice.mdc" and preamble:
            body = preamble + "\n\n" + body
        out = RULES_DIR / filename
        write_mdc(out, title, body, always_apply)
        written.append(filename)

    # Stub root file — SSOT is now .cursor/rules/
    stub = """# Regole importanti per lo sviluppo

> **Spostate in `.cursor/rules/*.mdc`** (injection Cursor via `alwaysApply`).
> Questo file resta come puntatore per link esistenti nel repository.

## Indice

| File | Contenuto |
|------|-----------|
| `.cursor/rules/00-indice.mdc` | Indice regole |
| `.cursor/rules/01-conferma-scrittura.mdc` | Regola 0 — conferma prima di scrivere |
| `.cursor/rules/02-sdd.mdc` | Regola 0b — Spec-Driven Development |
| `.cursor/rules/03-modello.mdc` | Regola 0c — DDD + UML + Statechart |
| `.cursor/rules/04-project-map.mdc` | Mappa del progetto |
| `.cursor/rules/05-documentazione.mdc` | Documentazione solo per l'agente |
| `.cursor/rules/06-metodo-analitico.mdc` | Metodo analitico |
| `.cursor/rules/07-analisi-architetturale.mdc` | Analisi architetturale |
| `.cursor/rules/08-dry-kiss-unificazioni.mdc` | DRY, KISS, unificazioni |
| `.cursor/rules/09-principio-certezza.mdc` | Principio di certezza |
| `.cursor/rules/10-revisione-codice.mdc` | Revisione completa del codice |
| `.cursor/rules/11-debug-testing.mdc` | Debug e testing |
| `.cursor/rules/12-build.mdc` | Build e verifica |
| `.cursor/rules/13-dettaglio-codice.mdc` | Comunicazione con l'utente |
| `.cursor/rules/14-workflow-riepilogo.mdc` | Workflow completo |

Backup pre-migrazione: `.cursor/rules/_source.cursor-rules.md`.
"""
    SOURCE.write_text(stub, encoding="utf-8")

    backup = RULES_DIR / "_source.cursor-rules.md"
    backup.write_text(source_text, encoding="utf-8")

    print(f"Wrote {len(written)} rule files to {RULES_DIR}")
    for name in written:
        print(f"  - {name}")


if __name__ == "__main__":
    main()
