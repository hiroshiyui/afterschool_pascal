#!/usr/bin/env python3
"""Do the two targets this compiler emits for lay a frame out the same way?

`LlSize` and `LlAlign` in selfhost/compiler.pas are hand-written, because the
emitter has no `DataLayout` to ask (ADR-0028). They decide two things -- the
length of a whole-variable copy, and the size `new` allocates -- and they answer
with one number for every target. That is only correct while every target the
compiler admits agrees about every frame it emits, and until this file nothing
asked. The 25-target comparison doc/roadmap.md records was made once, by hand,
on 2026-08-22; a divergence afterwards would have gone unnoticed until somebody
tried the other machine. Don't write the offset count into this comment -- it
is every field of every frame emitted for selfhost/compiler.pas and moves with
each declaration added there, so a number here would be a third opinion beside
the roadmap's and this run's. The run prints it.

What it does: emits every frame type this compiler produces -- from
selfhost/compiler.pas for breadth and from target_layout.pas for the types the
compiler has no frame slot of -- as a module of `ptrtoint getelementptr`
constants, one per field offset and one per frame size, then assembles that
module once per target and compares the numbers LLVM folded them to.

It fails in both directions. A field that moves between two targets fails,
which is the divergence. So does a run that compared nothing: an empty
comparison is what a clean run and a run that reached no frame at all both
produce, which is `difftest`'s lesson and the reason the count is asserted
rather than reported.

The target list is read from the compiler's own refusal, so a third target
admitted to `TargetIndex` is compared here without this file being edited --
and the refusal already says "needs its layout compared against LlSize and
LlAlign first", which is exactly this comparison.

Needs `clang` and nothing else of LLVM's (ADR-0085): a target's datalayout is
asked of clang, and clang is what folds the constants.
"""

import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PASCALC = os.environ.get("PASCALC", os.path.join(ROOT, "build", "bin", "pascalc"))
CLANG = os.environ.get("APASCAL_CLANG", "clang")

# The two sources whose frames are compared. The compiler is the breadth; the
# probe is the depth -- see its header.
SOURCES = [
    os.path.join(ROOT, "selfhost", "compiler.pas"),
    os.path.join(ROOT, "tests", "checks", "target_layout.pas"),
]

# A floor, not a count. The exact number moves with every declaration added to
# the compiler, so pinning it would make this gate fail for reasons that are
# not about layout at all; what it has to refuse is the *empty* comparison, and
# anything of this order says both sources were read and parsed.
MIN_OFFSETS = 1000

FRAME = re.compile(r"^(%frame\d+) = type (\{.*\})$")


def die(msg):
    sys.stderr.write("target-layout: " + msg + "\n")
    sys.exit(1)


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def admitted_targets():
    """The targets the compiler emits for, read from its own refusal.

    Asking the compiler rather than listing them here is ADR-0144's rule: a
    list written in a checker is a second opinion free to drift from the thing
    it checks, and a target admitted to TargetIndex without being compared is
    precisely the state this gate exists to make impossible.
    """
    r = run([PASCALC, "--target=+no-such-target",
             os.path.join(ROOT, "tests", "hello.pas"), "-o", os.devnull])
    for line in (r.stdout + r.stderr).splitlines():
        m = re.match(r"pascalc: this compiler emits for (.*)$", line.strip())
        if m:
            names = re.split(r",\s*|\s+and\s+", m.group(1))
            return [n for n in names if n]
    die("the compiler did not name its targets; --target= refusal said:\n"
        + (r.stdout + r.stderr))


def datalayout_of(target):
    """clang's own datalayout for a target -- never a transcription of one.

    The module states it, and clang then *overrides* it with the one for the
    `--target=` it was given, silently -- which is ADR-0156's measurement and
    the reason the emitted header lines are advisory on the pascalcc path. So
    the authority for what is compared here is `--target=` and not this line.
    Stating it anyway costs nothing and makes the probe module say what it
    means, which matters the day some consumer stops overriding.
    """
    r = run([CLANG, "--target=" + target, "-x", "c", os.devnull,
             "-S", "-emit-llvm", "-o", "-"])
    if r.returncode != 0:
        die("clang has no backend for %s:\n%s" % (target, r.stderr))
    for line in r.stdout.splitlines():
        if line.startswith("target datalayout"):
            return line
    die("clang stated no datalayout for " + target)


def top_level_fields(body):
    """How many fields a struct body has, counting only the top level.

    Commas nest -- `{ i32, { i8, i8 } }` has two fields and three commas, and
    an array's `[3 x { ... }]` has more -- so this counts depth rather than
    separators. Getting it wrong makes the getelementptr indices wrong and the
    comparison silently narrower than it looks.
    """
    depth, n = 0, 0
    for ch in body[1:-1]:
        if ch in "{[<":
            depth += 1
        elif ch in "}]>":
            depth -= 1
        elif ch == "," and depth == 0:
            n += 1
    return n + 1 if body[1:-1].strip() else 0


def frames_of(path):
    """The frame type definitions this compiler emits for one source."""
    with tempfile.NamedTemporaryFile(suffix=".ll", delete=False) as f:
        out = f.name
    try:
        r = run([PASCALC, path, "-o", out])
        if r.returncode != 0:
            die("compiling %s failed:\n%s" % (path, r.stdout + r.stderr))
        found = []
        for line in open(out):
            m = FRAME.match(line.rstrip("\n"))
            if m:
                found.append((m.group(1), m.group(2)))
        if not found:
            die("no frame types in the IR for " + path)
        return found
    finally:
        os.unlink(out)


def build_module(sources):
    """One module of folded constants, and the names to read back out."""
    types, consts, names = [], [], []
    for i, path in enumerate(sources):
        for name, body in frames_of(path):
            # Renamed per source, because two sources both start at %frame1.
            # `name` arrives with its sigil, so it is dropped and one is put
            # back: source 0's %frame1 becomes %s0frame1.
            tag = "%s%d%s" % ("%s", i, name[1:])
            types.append("%s = type %s" % (tag, body))
            sym = "z%d_%s" % (i, name[1:])
            consts.append("@%s_size = global i64 ptrtoint (ptr getelementptr "
                          "(%s, ptr null, i32 1) to i64)" % (sym, tag))
            names.append(sym + "_size")
            for k in range(top_level_fields(body)):
                consts.append(
                    "@%s_f%d = global i64 ptrtoint (ptr getelementptr "
                    "(%s, ptr null, i32 0, i32 %d) to i64)" % (sym, k, tag, k))
                names.append("%s_f%d" % (sym, k))
    return types, consts, names


# One 64-bit datum, however this target's assembler spells it.
WIDE = re.compile(r"^\s*\.(?:quad|xword|8byte|dword)\s+(?:0\s*\+\s*)?(-?\d+)")
# ...and the half of one, for the targets that have no 64-bit directive: a
# 32-bit machine writes an i64 constant as two of these, and which half comes
# first is the datalayout's `e`/`E`.
HALF = re.compile(r"^\s*\.(?:long|word|4byte)\s+(?:0\s*\+\s*)?(-?\d+)")
# Mach-O gives a global a leading underscore. Stripping one is safe here and
# only here: every name this gate generates begins with `z`, so there is no ELF
# symbol `_x` for it to collide with a symbol `x`.
LABEL = re.compile(r"^_?([A-Za-z.$][\w.$]*):")
# ...and Mach-O does not emit a directive at all for a global whose value is
# zero, which is every frame's field 0. Without this the gate reads 617 fewer
# offsets than it asked for and says so, which is the right failure and not a
# useful one.
ZEROFILL = re.compile(r"^\s*\.zerofill\s+[^,]+,[^,]+,_?([\w.$]+),")


def offsets_for(target, dl, types, consts):
    """Assemble the module for one target and read the folded values back.

    By symbol rather than by position: the assembler is free to order globals
    as it likes, and a comparison that assumed declaration order would compare
    two targets' *sortings* as readily as their layouts.
    """
    src = "\n".join([dl, 'target triple = "%s"' % target] + types + consts) + "\n"
    with tempfile.NamedTemporaryFile("w", suffix=".ll", delete=False) as f:
        f.write(src)
        path = f.name
    try:
        r = run([CLANG, "--target=" + target, "-S", "-o", "-", path])
        if r.returncode != 0:
            die("assembling the probe for %s failed:\n%s" % (target, r.stderr))
        little = not dl.split('"')[1].startswith("E")
        vals, pending, half = {}, None, None
        for line in r.stdout.splitlines():
            m = ZEROFILL.match(line)
            if m:
                vals.setdefault(m.group(1), 0)
                continue
            m = LABEL.match(line)
            if m:
                pending, half = m.group(1), None
                continue
            if pending is None:
                continue
            m = WIDE.match(line)
            if m:
                vals.setdefault(pending, int(m.group(1)))
                pending = None
                continue
            m = HALF.match(line)
            if m:
                if half is None:
                    half = int(m.group(1))
                else:
                    lo, hi = (half, int(m.group(1))) if little \
                        else (int(m.group(1)), half)
                    vals.setdefault(pending, (hi << 32) | lo)
                    pending, half = None, None
        return vals
    finally:
        os.unlink(path)


def main():
    if not os.path.exists(PASCALC):
        die("no compiler at %s -- build first, or set PASCALC" % PASCALC)
    targets = admitted_targets()
    if len(targets) < 2:
        die("only one target is admitted (%s); nothing to compare, and a "
            "layout gate that compares one target asserts nothing"
            % ", ".join(targets))

    types, consts, names = build_module(SOURCES)
    if len(names) < MIN_OFFSETS:
        die("only %d offsets to compare, below the floor of %d -- the frame "
            "extraction reached almost nothing" % (len(names), MIN_OFFSETS))

    measured = {}
    for t in targets:
        vals = offsets_for(t, datalayout_of(t), types, consts)
        missing = [n for n in names if n not in vals]
        if missing:
            die("%s: %d of %d constants were not folded to a number "
                "(first: %s)" % (t, len(missing), len(names), missing[0]))
        measured[t] = vals

    base = targets[0]
    bad = []
    for t in targets[1:]:
        for n in names:
            if measured[t][n] != measured[base][n]:
                bad.append((n, base, measured[base][n], t, measured[t][n]))

    if bad:
        sys.stderr.write(
            "target-layout: %d of %d offsets differ between targets.\n"
            "LlSize and LlAlign answer with one number for every target, so a "
            "difference here means\nthe emitted frames are wrong for at least "
            "one of them -- see ADR-0028.\n" % (len(bad), len(names)))
        for n, a, av, b, bv in bad[:20]:
            sys.stderr.write("  %-24s %s=%d  %s=%d\n" % (n, a, av, b, bv))
        if len(bad) > 20:
            sys.stderr.write("  ... and %d more\n" % (len(bad) - 20))
        sys.exit(1)

    print("target-layout: %d offsets identical across %s"
          % (len(names), ", ".join(targets)))


if __name__ == "__main__":
    main()
