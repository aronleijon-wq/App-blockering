"""Finds string literals in Swift source, including ones nested inside interpolations.

Shared by the translation tools: `localize.py` wraps user-facing literals in `L(...)`, and
`check_translations.py` makes sure every wrapped text has an English translation.
"""
import re


class Literal:
    def __init__(self, start, end, parts, multiline):
        self.start = start  # index of the opening quote
        self.end = end  # index after the closing quote
        self.parts = parts  # list of ("text", str) and ("interp", (start, end)) in source order
        self.multiline = multiline

    def key(self):
        """The lookup key: literal text with Swift escapes undone, `%` doubled and each interpolation as `%@`."""
        out = []
        for kind, value in self.parts:
            if kind == "text":
                out.append(unescape(value).replace("%", "%%"))
            else:
                out.append("%@")
        return "".join(out)

    def text(self):
        return "".join(unescape(v) if k == "text" else "…" for k, v in self.parts)


def unescape(raw):
    return (
        raw.replace("\\\\", "\x00")
        .replace('\\"', '"')
        .replace("\\n", "\n")
        .replace("\\t", "\t")
        .replace("\\'", "'")
        .replace("\x00", "\\")
    )


def scan(source):
    """Yields every literal (outer ones before the literals nested in their interpolations)."""
    literals = []
    _scan_code(source, 0, len(source), literals, depth_stop=False)
    return literals


def _scan_code(src, i, end, literals, depth_stop):
    """Scans code from i; when depth_stop, stops at the `)` closing an interpolation and returns its index."""
    depth = 0
    while i < end:
        c = src[i]
        if src.startswith("//", i):
            j = src.find("\n", i)
            i = end if j == -1 else j
            continue
        if src.startswith("/*", i):
            j = src.find("*/", i + 2)
            i = end if j == -1 else j + 2
            continue
        if c == "#" and i + 1 < end and src[i + 1] in '"#':
            # Raw string: skip it whole, it is never user-facing here.
            hashes = 0
            while src[i + hashes] == "#":
                hashes += 1
            quote_start = i + hashes
            if src.startswith('"""', quote_start):
                closing = '"""' + "#" * hashes
                j = src.find(closing, quote_start + 3)
            else:
                closing = '"' + "#" * hashes
                j = src.find(closing, quote_start + 1)
            i = end if j == -1 else j + len(closing)
            continue
        if c == '"':
            i = _scan_string(src, i, end, literals)
            continue
        if depth_stop:
            if c == "(":
                depth += 1
            elif c == ")":
                if depth == 0:
                    return i
                depth -= 1
        i += 1
    return i


def _scan_string(src, i, end, literals):
    multiline = src.startswith('"""', i)
    quote = '"""' if multiline else '"'
    j = i + len(quote)
    parts = []
    text_start = j
    index = len(literals)
    literals.append(None)  # keep outer before inner
    nested = []
    while j < end:
        if src[j] == "\\":
            if src[j + 1] == "(":
                parts.append(("text", src[text_start:j]))
                inner_start = j + 2
                close = _scan_code(src, inner_start, end, nested, depth_stop=True)
                parts.append(("interp", (inner_start, close)))
                j = close + 1
                text_start = j
                continue
            j += 2
            continue
        if src.startswith(quote, j):
            parts.append(("text", src[text_start:j]))
            literal = Literal(i, j + len(quote), [p for p in parts if p != ("text", "")], multiline)
            literals[index] = literal
            literals.extend(nested)
            return j + len(quote)
        j += 1
    raise ValueError(f"unterminated string at {i}")


def line_of(source, index):
    return source.count("\n", 0, index) + 1


L_CALL = re.compile(r"\bL\(\s*$")


def is_wrapped(source, literal):
    """Whether the literal is the argument of an `L(` call."""
    return bool(L_CALL.search(source[max(0, literal.start - 40):literal.start]))
