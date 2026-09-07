#!/usr/bin/env python3
"""Is every foreign scalar the width of its C type? (ADR-0364)

An `external` declaration names a Pascal type for each C parameter and for
the result, and the C type is often the *target's* width -- `long`, `size_t`,
`ssize_t`, `time_t`, a pointer -- where this language's `integer` and `int64`
are fixed. `clong` and `csize` (AP 6.4.2.7) exist so a binding can say
"whatever this target's is"; a binding that says `int64` instead is right on
every LP64 target and reads whatever the spare register held on i386.

**No behavioural case can hold this.** `PasProcess.Seconds` was bound that way
and answered 7682741216296735854 on CI's i386 container -- and the right epoch
on the machine that wrote the fix, where `edx` happened to be clean, so
`target32` was green there with the defect in it and the mutation putting
`int64` back survived (ADR-0363). What a gate can hold is the *declaration*:
every `external` whose signature names `int64` must be in the catalogue with
the C type that really is 64 bits everywhere, and every catalogued row must
still name a declaration. Both directions, like every catalogue here.

`integer` is not asked about: C `int` is 32 bits on every target this compiler
admits. `clong` and `csize` are the answer and are not asked about either.

The second half asks the *emitter* the same question: a slice crosses a
foreign call as an address and a count, and the count is a `size_t`. Compiled
for each target the compiler admits, the declaration the emitter writes must
carry that target's width -- `i32` on i386 -- which is a claim about
`selfhost/compiler.pas` and not about any module.

Usage:  tests/checks/foreign_width.py [--root DIR] [--pascalc PATH]
"""
import argparse, pathlib, re, subprocess, sys, tempfile

CATALOGUE = "tests/checks/foreign_int64.txt"
ROOTS = ("lib", "lsp")
FLOOR = 60          # externals a sweep must find, or it swept nothing

def declarations(src: str):
    """Every routine heading ending in `external '...'`, joined across lines.

    A heading may run to several lines and its parameter list may hold `;`
    itself, so the join is bounded by shape rather than by punctuation: lines
    are added until `external '` appears, or a line starts something else, or
    six lines have gone by -- no heading here is longer."""
    out = []
    lines = src.split("\n")
    # `var` is not in this list on purpose: a heading's second line may begin
    # with a `var` parameter, as ExtFileInfo's does.
    starts = re.compile(r"\s*(function|procedure|begin|end|import|export|\{|$)")
    i = 0
    while i < len(lines):
        m = re.match(r"\s*(function|procedure)\s+([A-Za-z_][A-Za-z0-9_]*)", lines[i])
        if not m:
            i += 1
            continue
        block = lines[i]
        j = i
        while "external '" not in block and j - i < 6 and j + 1 < len(lines) \
                and not starts.match(lines[j + 1]):
            j += 1
            block += " " + lines[j]
        if "external '" in block:
            out.append((i + 1, m.group(2), re.sub(r"\s+", " ", block)))
        i = j + 1
    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=str(pathlib.Path(__file__).resolve().parents[2]))
    ap.add_argument("--pascalc", default=None)
    args = ap.parse_args()
    root = pathlib.Path(args.root)
    found = {}
    total = 0
    for r in ROOTS:
        for p in sorted((root / r).rglob("*.pas")):
            for line, name, block in declarations(p.read_text(encoding="utf-8", errors="replace")):
                total += 1
                sig = block.split("external '")[0]
                if re.search(r"\bint64\b", sig, re.IGNORECASE):
                    found[f"{p.relative_to(root)}:{name}"] = line
    fails = []
    if total < FLOOR:
        fails.append(f"only {total} external declarations found under {ROOTS}; the sweep reads nothing")
    cat = {}
    for raw in (root / CATALOGUE).read_text().split("\n"):
        s = raw.strip()
        if not s or s.startswith("#"):
            continue
        key = s.split()[0]
        cat[key] = s
    for key, line in sorted(found.items()):
        if key not in cat:
            fails.append(f"{key} (line {line}) binds int64 and is not catalogued -- is the C type 64 bits on i386? "
                         f"If it is a long, size_t, ssize_t, time_t or a pointer, it is clong or csize; "
                         f"if it really is 64 bits everywhere, add a row to {CATALOGUE} saying which C type")
    for key in sorted(cat):
        if key not in found:
            fails.append(f"{CATALOGUE} names {key}, which no longer binds int64 -- remove the row")

    # --- the emitter's half: a slice's count is size_t, per target ---------
    pascalc = args.pascalc or str(root / "build" / "bin" / "pascalc")
    probe = "program w(output);\nfunction F(var b: array of char): csize; external 'readlink_probe';\nvar a: array [1..4] of char; n: csize;\nbegin n := F(a); writeln(n) end.\n"
    want = {"x86_64-pc-linux-gnu": "i64", "aarch64-linux-gnu": "i64", "i386-pc-linux-gnu": "i32"}
    if pathlib.Path(pascalc).exists():
        with tempfile.TemporaryDirectory() as d:
            src = pathlib.Path(d) / "w.pas"; src.write_text(probe)
            for tgt, w in want.items():
                ll = pathlib.Path(d) / f"{tgt}.ll"
                r = subprocess.run([pascalc, f"--target={tgt}", str(src), "-o", str(ll)], capture_output=True, text=True)
                if r.returncode != 0:
                    fails.append(f"the probe would not compile for {tgt}: {r.stdout.strip()[:200]}"); continue
                text = ll.read_text()
                decl = re.search(r"declare\s+\S+\s+@readlink_probe\(([^)]*)\)", text)
                if not decl:
                    fails.append(f"no declaration of the probe's foreign routine for {tgt}"); continue
                if decl.group(1).replace(" ", "") != f"ptr,{w}":
                    fails.append(f"for {tgt} the emitter declares a slice as ({decl.group(1)}) and size_t there is {w} (ADR-0364)")
    else:
        print(f"foreign-width: no compiler at {pascalc}; the emitter's half was not asked", file=sys.stderr)

    if fails:
        print("foreign-width:", file=sys.stderr)
        for f in fails:
            print("  " + f, file=sys.stderr)
        return 1
    print(f"foreign-width: {total} external declarations under {ROOTS}, {len(found)} bind int64 and every one is catalogued; "
          f"a slice's count is size_t on each of {len(want)} targets")
    return 0

if __name__ == "__main__":
    sys.exit(main())
