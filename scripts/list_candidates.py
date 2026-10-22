import os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
from swift_strings import scan, line_of

root = sys.argv[1]
dirs = ["Paus", "Shared", "PausCore/Sources", "ReportUI", "PausReport", "PausWidgets", "PausMonitor", "PausShieldConfiguration", "PausShieldAction"]
for d in dirs:
    for dp, _, fs in os.walk(os.path.join(root, d)):
        for f in sorted(fs):
            if not f.endswith(".swift"):
                continue
            p = os.path.join(dp, f)
            src = open(p).read()
            for lit in scan(src):
                t = lit.text()
                if re.search(r"[A-Za-zåäöÅÄÖ]", t):
                    print(f"{p[len(root)+1:]}:{line_of(src, lit.start)}\t{'M' if lit.multiline else ''}\t{lit.key()!r}")
