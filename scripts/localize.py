"""Wraps user-facing Swedish string literals in `L(...)` so they can be translated.

Usage: python3 scripts/localize.py <repo> <keys-file>
The keys file lists, one Python string literal per line, the keys to wrap (as `swift_strings.Literal.key()` gives them).
"""
import ast
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from swift_strings import scan, is_wrapped

DIRS = ["Paus", "Shared", "PausCore/Sources", "ReportUI", "PausReport", "PausWidgets", "PausMonitor", "PausShieldConfiguration", "PausShieldAction"]


def main(root, keys_file):
    keys = {ast.literal_eval(line) for line in open(keys_file) if line.strip()}
    changed = 0
    for d in DIRS:
        for dp, _, fs in os.walk(os.path.join(root, d)):
            for f in fs:
                if not f.endswith(".swift") or f == "Translations.swift":
                    continue
                path = os.path.join(dp, f)
                src = open(path).read()
                targets = [lit for lit in scan(src) if not lit.multiline and lit.key() in keys and not is_wrapped(src, lit)]
                # Insert from the end of the file backwards, so literals nested in others keep valid offsets.
                insertions = [(lit.start, "L(") for lit in targets] + [(lit.end, ")") for lit in targets]
                for position, text in sorted(insertions, key=lambda item: item[0], reverse=True):
                    src = src[:position] + text + src[position:]
                changed += len(targets)
                if targets:
                    open(path, "w").write(src)
    print("wrapped", changed)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
