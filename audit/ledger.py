#!/usr/bin/env python3
"""Datum audit ledger.

Source of truth: audit/ledger.src (hand-written), one row per entry:

    name<TAB>level<TAB>kind<TAB>repairs

  name     fully qualified Rocq name (Datum.<Module>.<ident>)
  level    Micro | Meso | Macro
  kind     QED (positive result) | QEX (Qed-closed counterexample)
  repairs  QED: "-".  QEX: comma-separated QED names that replace the
           refuted claim, or "open" if no repair exists yet.

Subcommands:

  emit     check the source rows and theory coverage, write audit/Ledger.v
  report   read the Print Assumptions output produced by compiling
           audit/Ledger.v, apply the axiom policy, write audit/ledger.tsv
           and audit/counts.tsv
  ratchet BASE_COUNTS
           compare audit/counts.tsv against a baseline counts file

Axiom policy (tiers):

  Tier 0   Closed under the global context.
  Tier 1   Only axioms listed in audit/allowlist.txt (Reals construction).
  Tier 2   Additionally uses an axiom registered for this theorem in
           audit/exceptions.tsv ("axiom" rows; intended for classic).
  QEX entries must be Tier 0 or 1: exceptions never apply to them.
  Anything else fails.
"""

import os
import re
import sys

ROOT = os.environ.get("DATUM_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIT = os.path.join(ROOT, "audit")
THEORIES = os.path.join(ROOT, "theories")
SRC = os.path.join(AUDIT, "ledger.src")
LEDGER_V = os.path.join(AUDIT, "Ledger.v")
OUT_DIR = os.path.join(AUDIT, "_out")
LEDGER_TSV = os.path.join(AUDIT, "ledger.tsv")
COUNTS_TSV = os.path.join(AUDIT, "counts.tsv")
ALLOWLIST = os.path.join(AUDIT, "allowlist.txt")
EXCEPTIONS = os.path.join(AUDIT, "exceptions.tsv")

LIB = "Datum"
LEVELS = ("Micro", "Meso", "Macro")
KINDS = ("QED", "QEX")
NAME_RE = re.compile(r"^[A-Za-z_][\w']*(\.[A-Za-z_][\w']*)+$")
COUNTEREXAMPLE = LIB + ".Ledger.Core.Counterexample"

errors = []


def err(msg):
    errors.append(msg)


def finish():
    if errors:
        for e in errors:
            print("ledger: error: " + e, file=sys.stderr)
        sys.exit(1)


def read_rows(path, ncols):
    """Tab-separated rows; '#' comments and blank lines ignored."""
    rows = []
    if not os.path.exists(path):
        return rows
    with open(path, encoding="utf-8") as f:
        for lineno, line in enumerate(f, 1):
            line = line.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            cols = line.split("\t")
            if len(cols) != ncols:
                err(f"{os.path.relpath(path, ROOT)}:{lineno}: expected "
                    f"{ncols} tab-separated columns, got {len(cols)}")
                continue
            rows.append((lineno, [c.strip() for c in cols]))
    return rows


def read_lines(path):
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as f:
        return [l.strip() for l in f
                if l.strip() and not l.lstrip().startswith("#")]


# --------------------------------------------------------------------------
# Source rows

def load_src():
    entries = []
    seen = {}
    for lineno, (name, level, kind, repairs) in read_rows(SRC, 4):
        where = f"audit/ledger.src:{lineno}"
        if not NAME_RE.match(name) or not name.startswith(LIB + "."):
            err(f"{where}: name must be fully qualified under {LIB}: {name}")
        if level not in LEVELS:
            err(f"{where}: level must be one of {'|'.join(LEVELS)}: {level}")
        if kind not in KINDS:
            err(f"{where}: kind must be QED or QEX: {kind}")
        if name in seen:
            # Mutual exclusion: one name, one row, one ledger.
            err(f"{where}: {name} already listed at line {seen[name]}")
            continue
        seen[name] = lineno
        if kind == "QED":
            if repairs != "-":
                err(f"{where}: QED rows take '-' in the repairs column")
            reps = []
        else:
            if repairs in ("", "-"):
                err(f"{where}: QEX row needs repairs or the 'open' marker")
                reps = []
            elif repairs == "open":
                reps = None
            else:
                reps = [r.strip() for r in repairs.split(",")]
        entries.append({"name": name, "level": level, "kind": kind,
                        "repairs": reps, "line": lineno})
    qed = {e["name"] for e in entries if e["kind"] == "QED"}
    for e in entries:
        for r in e["repairs"] or []:
            if r not in qed:
                err(f"audit/ledger.src:{e['line']}: {e['name']} repairs "
                    f"{r}, which is not a QED row in the ledger")
    return entries


# --------------------------------------------------------------------------
# Theory coverage: every exported Theorem/Lemma/... must have a ledger row.

DECL_RE = re.compile(
    r"^\s*(?:#\[[^\]]*\]\s*)*(Local\s+|Global\s+)?"
    r"(Theorem|Lemma|Corollary|Proposition|Fact|Remark)\s+([A-Za-z_][\w']*)")
LOCAL_ATTR_RE = re.compile(r"#\[\s*local\s*\]")
SECTION_RE = re.compile(r"^\s*Section\s+([A-Za-z_][\w']*)\s*\.")
MODULE_RE = re.compile(
    r"^\s*Module\s+(?!Type\b)(?:(?:Import|Export)\s+)?([A-Za-z_][\w']*)"
    r"[^:=.]*\.\s*$")
END_RE = re.compile(r"^\s*End\s+([A-Za-z_][\w']*)\s*\.")


def strip_comments(text):
    out, depth, i = [], 0, 0
    while i < len(text):
        if text.startswith("(*", i):
            depth += 1
            i += 2
        elif depth and text.startswith("*)", i):
            depth -= 1
            i += 2
        else:
            if not depth or text[i] == "\n":
                out.append(text[i])
            i += 1
    return "".join(out)


def theory_files():
    for d, _, files in os.walk(THEORIES):
        for f in sorted(files):
            if f.endswith(".v"):
                yield os.path.join(d, f)


def module_of(path):
    rel = os.path.relpath(path, THEORIES)[:-2]
    return LIB + "." + rel.replace(os.sep, ".")


def exported_theorems():
    found = {}
    for path in theory_files():
        mod = module_of(path)
        with open(path, encoding="utf-8") as f:
            text = strip_comments(f.read())
        stack = []
        for lineno, line in enumerate(text.splitlines(), 1):
            m = SECTION_RE.match(line)
            if m:
                stack.append(("S", m.group(1)))
                continue
            m = MODULE_RE.match(line)
            if m:
                stack.append(("M", m.group(1)))
                continue
            m = END_RE.match(line)
            if m and stack and stack[-1][1] == m.group(1):
                stack.pop()
                continue
            m = DECL_RE.match(line)
            if m:
                if m.group(1) and m.group(1).strip() == "Local":
                    continue
                if LOCAL_ATTR_RE.search(line):
                    continue
                prefix = [n for k, n in stack if k == "M"]
                name = ".".join([mod] + prefix + [m.group(3)])
                found[name] = f"{os.path.relpath(path, ROOT)}:{lineno}"
    return found


def library_of(name):
    """Longest prefix of [name] that is a file under theories/."""
    parts = name.split(".")
    for i in range(len(parts) - 1, 1, -1):
        rel = os.path.join(THEORIES, *parts[1:i]) + ".v"
        if os.path.exists(rel):
            return ".".join(parts[:i])
    return None


# --------------------------------------------------------------------------
# emit

def cmd_emit():
    entries = load_src()
    names = {e["name"] for e in entries}
    for thm, where in sorted(exported_theorems().items()):
        if thm not in names:
            err(f"{where}: {thm} is not registered in audit/ledger.src")
    libs = set()
    for e in entries:
        for n in [e["name"]] + (e["repairs"] or []):
            lib = library_of(n)
            if lib is None:
                err(f"audit/ledger.src:{e['line']}: no theories/ file "
                    f"provides {n}")
            else:
                libs.add(lib)
    finish()
    libs.add(LIB + ".Ledger.Core")

    out = ["(* GENERATED by audit/ledger.py from audit/ledger.src."
           " Do not edit. *)", ""]
    out += [f"Require {lib}." for lib in sorted(libs)]
    out += ["", "(** QED ledger: positive results. *)"]
    for e in entries:
        if e["kind"] == "QED":
            out.append(f"Check {e['name']}.")
    out += ["", "(** QEX ledger: each entry must inhabit Counterexample;"
            " each repair must exist. *)"]
    for e in entries:
        if e["kind"] == "QEX":
            out.append(f"Check ({e['name']} : {COUNTEREXAMPLE} _).")
            for r in e["repairs"] or []:
                out.append(f"Check {r}.")
    out += ["", "(** Assumptions, one file per entry under audit/_out/. *)"]
    for e in entries:
        out.append(f'Redirect "audit/_out/{e["name"]}" '
                   f"Print Assumptions {e['name']}.")
    with open(LEDGER_V, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")


# --------------------------------------------------------------------------
# report

SECTION_HDR_RE = re.compile(r"^(Section Variables|Axioms|Opaque constants|"
                            r"Transparent constants):\s*$")
AXIOM_LINE_RE = re.compile(r"^([^\s:][^\s]*)\s+:")


def parse_assumptions(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    if "Closed under the global context" in text:
        return []
    axioms, section = [], None
    for line in text.splitlines():
        m = SECTION_HDR_RE.match(line)
        if m:
            section = m.group(1)
            continue
        if section is None:
            continue
        m = AXIOM_LINE_RE.match(line)
        if m:
            axioms.append(m.group(1))
    if section is None:
        err(f"{os.path.relpath(path, ROOT)}: unrecognised Print Assumptions "
            f"output")
    return sorted(set(axioms))


def cmd_report():
    entries = load_src()
    allow = set(read_lines(ALLOWLIST))
    exc_axiom = {}
    for _, (kind, subject, detail, why) in read_rows(EXCEPTIONS, 4):
        if kind == "axiom":
            exc_axiom.setdefault(subject, set()).add(detail)
    finish()

    rows = []
    for e in entries:
        path = os.path.join(OUT_DIR, e["name"] + ".out")
        if not os.path.exists(path):
            err(f"{e['name']}: no assumptions output (was audit/Ledger.v "
                f"compiled?)")
            continue
        axioms = parse_assumptions(path)
        outside = [a for a in axioms if a not in allow]
        if not axioms:
            tier = 0
        elif not outside:
            tier = 1
        else:
            tier = 2
            if e["kind"] == "QEX":
                err(f"{e['name']}: QEX entries must be Tier 0 or 1; uses "
                    f"{', '.join(outside)}")
            else:
                unregistered = [a for a in outside
                                if a not in exc_axiom.get(e["name"], ())]
                if unregistered:
                    err(f"{e['name']}: axiom(s) outside the allowlist "
                        f"without an exception row: "
                        f"{', '.join(unregistered)}")
        if e["kind"] == "QED":
            reps = "-"
        elif e["repairs"] is None:
            reps = "open"
        else:
            reps = ",".join(e["repairs"])
        rows.append([e["name"], e["level"], e["kind"], str(tier),
                     ",".join(axioms) or "-", reps])
    finish()

    with open(LEDGER_TSV, "w", encoding="utf-8") as f:
        f.write("# GENERATED by audit/ledger.py. Do not edit.\n")
        f.write("name\tlevel\tkind\ttier\tassumptions\trepairs\n")
        for r in rows:
            f.write("\t".join(r) + "\n")

    with open(COUNTS_TSV, "w", encoding="utf-8") as f:
        f.write("# GENERATED by audit/ledger.py. Do not edit.\n")
        f.write("level\tkind\tcount\n")
        for lv in LEVELS:
            for k in KINDS:
                n = sum(1 for e in entries
                        if e["level"] == lv and e["kind"] == k)
                f.write(f"{lv}\t{k}\t{n}\n")
        n_open = sum(1 for e in entries
                     if e["kind"] == "QEX" and e["repairs"] is None)
        f.write(f"*\topen\t{n_open}\n")
    print(f"ledger: {len(rows)} entries, {n_open} open")


# --------------------------------------------------------------------------
# ratchet

def read_counts(path):
    counts = {}
    for _, (lv, k, n) in read_rows(path, 3):
        if lv == "level":
            continue
        counts[(lv, k)] = int(n)
    return counts


def cmd_ratchet(base_path):
    base = read_counts(base_path)
    new = read_counts(COUNTS_TSV)
    allowed = {}
    for _, (kind, subject, detail, why) in read_rows(EXCEPTIONS, 4):
        if kind == "ratchet":
            allowed[subject] = detail
    finish()
    for (lv, k), old in sorted(base.items()):
        cur = new.get((lv, k), 0)
        if k == "open":
            if cur > old:
                print(f"::warning::ledger: open QEX entries rose "
                      f"{old} -> {cur}")
            continue
        if cur < old:
            key = f"{lv}/{k}"
            if allowed.get(key) == str(cur):
                print(f"ledger: {key} dropped {old} -> {cur} "
                      f"(exception registered)")
            else:
                err(f"{key} count dropped {old} -> {cur}; add a 'ratchet' "
                    f"row '{key}<TAB>{cur}' to audit/exceptions.tsv with a "
                    f"justification")
    finish()
    print("ledger: ratchet ok")


def main(argv):
    if len(argv) == 2 and argv[1] == "emit":
        cmd_emit()
    elif len(argv) == 2 and argv[1] == "report":
        cmd_report()
    elif len(argv) == 3 and argv[1] == "ratchet":
        cmd_ratchet(argv[2])
    else:
        print(__doc__, file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main(sys.argv)
