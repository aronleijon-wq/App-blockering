"""Fails when a text in `L(...)` has no English translation in PausCore's Translations.swift.

Run from the repository root: python3 scripts/check_translations.py
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from swift_strings import scan, is_wrapped

DIRS = ["Paus", "Shared", "PausCore/Sources", "ReportUI", "PausReport", "PausWidgets", "PausMonitor", "PausShieldConfiguration", "PausShieldAction"]
TRANSLATIONS = "PausCore/Sources/PausCore/Translations.swift"


def translated_keys():
    source = open(TRANSLATIONS).read()
    keys = set()
    for literal in scan(source):
        # Keys are the literals that start a dictionary entry: `"key": "value",`.
        rest = source[literal.end:literal.end + 2]
        if rest.startswith(":"):
            keys.add(literal.text())
    return keys


def main():
    known = translated_keys()
    missing = []
    for d in DIRS:
        for dp, _, fs in os.walk(d):
            for f in sorted(fs):
                if not f.endswith(".swift") or f == "Translations.swift":
                    continue
                path = os.path.join(dp, f)
                source = open(path).read()
                for literal in scan(source):
                    if is_wrapped(source, literal) and literal.key() not in known:
                        line = source.count("\n", 0, literal.start) + 1
                        missing.append(f"{path}:{line}: {literal.key()!r}")
    if missing:
        print("Texts without an English translation in", TRANSLATIONS)
        print("\n".join(missing))
        sys.exit(1)
    print(f"All texts are translated ({len(known)} translations).")


if __name__ == "__main__":
    main()
