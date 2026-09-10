#!/usr/bin/env python3
"""Does every target this compiler emits for lay a frame out the way it thinks?

`LlSize` and `LlAlign` in selfhost/compiler.pas are hand-written, because the
emitter has no `DataLayout` to ask (ADR-0028). They decide two things -- the
length of a whole-variable copy, and the size `new` allocates -- and until
ADR-0325 they answered with one number for every target. The 25-target
comparison doc/roadmap.md records was made once, by hand, on 2026-08-22; a
divergence afterwards would have gone unnoticed until somebody tried the other
machine.

**The question this asks changed when i386 was admitted** (ADR-0325), and it
had to: *do the targets agree with each other* is a claim a 32-bit target
falsifies by existing, and answering it would have meant refusing the port
rather than checking it. Two claims replace it, and together they are what the
one claim was standing in for.

  1. **Targets whose layout arithmetic is identical lay a frame out
     identically.** Every admitted target is put in a class by what the
     compiler answers for the six probe shapes below, and within each class
     the comparison is the old one, unchanged and as strict. It was a class
     per *word size* until ADR-0383: wasm32 is ILP32 like i386 and aligns an
     i64 to eight where i386 aligns one to four, so the word size stopped
     deciding the layout the moment there were two 32-bit targets.

  2. **The numbers the compiler varies are the numbers clang says.**
     `PtrSize`, `WordAlign` and -- since ADR-0383 -- `WideAlign` are the whole
     of what is target-dependent, so a probe of six one-field-after-a-byte structs is
     assembled for each target and the folded offsets are compared against
     what the compiler emits for a pointer, an i64, a double, a vector, an
     i256 and a two-pointer pair. This is the half that did not exist before,
     because there was nothing to vary.

Claim 2 is asked of every target including the LP64 ones, so a wrong answer for
a target that has always worked fails here too. Don't write the offset count
into this comment -- it
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

The target list is read from the compiler's own refusal, so a fourth target
admitted to `TargetIndex` is compared here without this file being edited --
and the refusal already says "needs its layout compared against LlSize and
LlAlign first", which is exactly this comparison. A target that lays out like no other
admitted one is compared by claim 2 and by nothing else, which is stated
rather than hidden: the run prints the classes.

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

# How many admitted targets must actually be compared. Abstaining is right
# where this machine's clang cannot answer, and a gate that abstains for
# everything prints a clean line having asked nothing -- so the floor, and it
# is set to what the oldest runner here can answer for.
COMPARE_FLOOR = 4
CLANG = os.environ.get("APASCAL_CLANG", "clang")

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import components                                    # noqa: E402

# The sources whose frames are compared, each as the argument list that
# translates it. The compiler is the breadth -- all three of its
# program-components since ADR-0233, because a frame belongs to the component
# that declares the block -- and the probe is the depth; see its header.
SOURCES = [components.translate(ROOT, name)
           for name in components.COMPONENTS] + [
    [os.path.join(ROOT, "tests", "checks", "target_layout.pas")],
]

# A floor, not a count. The exact number moves with every declaration added to
# the compiler, so pinning it would make this gate fail for reasons that are
# not about layout at all; what it has to refuse is the *empty* comparison, and
# anything of this order says both sources were read and parsed.
MIN_OFFSETS = 1000

FRAME = re.compile(r"^(%frame\d+) = type (\{.*\})$")
# `--dump-layout`'s own first line per record (ADR-0185).
RECORD = re.compile(r"^record (\w+) size=(\d+) align=(\d+)")


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
        # **None and not a refusal** (ADR-0384). This died until wasm32 was
        # admitted, and could: every target here was one any clang has. The
        # macOS runner's clang has no WebAssembly backend at all -- *no
        # available targets are compatible with triple* -- which is a fact
        # about that machine and nothing about this compiler, and it turned
        # the gate red on a runner that cannot answer.
        return None
    for line in r.stdout.splitlines():
        if line.startswith("target datalayout"):
            return line
    return None


# The fields of a datalayout that decide what this compiler lays out. It is an
# **allowlist**, and it started as the opposite (ADR-0385): dropping the fields
# that obviously decide nothing meant curating a list against every LLVM
# release, and two of them arrived within the hour -- an x86 host states
# `p270`/`p271`/`p272` for *any* target and an arm64 one does not, and clang 19
# writes `Fn32` where clang 18 writes nothing. Neither decides the size or the
# alignment of a single type here, and both abstained three targets at once.
#
# What is kept is what `LlSize` and `LlAlign` read: the endianness, the default
# pointer, and the alignment of an integer, a float, a vector or an aggregate.
# Everything else is a symbol mangling (`m:`), a set of native widths (`n`), a
# stack (`S`), a function-pointer alignment (`Fn`), a non-default address space
# or the list naming them (`ni`) -- vocabulary this emitter never uses.
#
# **The safe direction is to compare too much rather than too little.** A field
# that matters and is not allowed here makes two clangs *look* alike, and claim
# 2 then fails loudly on the folded numbers; the cost is a message about the
# wrong thing, not a wrong answer. Abstaining wrongly is the one that hides.
MODELLED = re.compile(r"^(?:[eE]|p:|[ivfa]\d*:)")


def modelled(line):
    body = line.split('"')[1] if '"' in line else line
    return frozenset(f for f in body.split("-") if MODELLED.match(f))


def emitted_datalayout(target):
    """The datalayout line *this compiler* writes for the target.

    What claim 2 compares is the compiler's arithmetic against LLVM's for one
    layout, so the two have to be talking about the same layout. They were, on
    every target here, until wasm32: its datalayout has grown fields between
    LLVM releases, and the aarch64 runner's clang names no `i128:128` for it,
    so an i256 aligns to 8 there and to 16 here. That is not the compiler
    disagreeing with LLVM -- it is two LLVMs disagreeing with each other, and
    folding it into claim 2 reported four correct numbers as a defect."""
    with tempfile.NamedTemporaryFile("w", suffix=".pas", delete=False) as f:
        f.write("program d(output);\nbegin writeln(1) end.\n")
        path = f.name
    out = path + ".ll"
    try:
        r = run([PASCALC, "--target=" + target, path, "-o", out])
        if r.returncode != 0 or not os.path.exists(out):
            die("this compiler could not emit for %s, which it admits:\n%s"
                % (target, r.stdout + r.stderr))
        with open(out) as f:
            for line in f:
                if line.startswith("target datalayout"):
                    return line.rstrip("\n")
        die("this compiler stated no datalayout for " + target)
    finally:
        os.unlink(path)
        if os.path.exists(out):
            os.unlink(out)


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


def frames_of(argv, target):
    """The frame type definitions this compiler emits for one source.

    `argv` is the whole translation -- a component's `--import` chain and then
    the component (ADR-0233) -- so the source it is *of* is its last word."""
    path = argv[-1]
    with tempfile.NamedTemporaryFile(suffix=".ll", delete=False) as f:
        out = f.name
    try:
        r = run([PASCALC, "--target=" + target, *argv, "-o", out])
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


def build_module(sources, target):
    """One module of folded constants, and the names to read back out.

    Per target since ADR-0325: the compiler emits different frame *types* for
    targets of different word sizes, so a module built once and assembled
    twice would compare one target's IR laid out two ways -- which is a
    question about LLVM and not about this compiler.
    """
    types, consts, names = [], [], []
    for i, argv in enumerate(sources):
        for name, body in frames_of(argv, target):
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


# One 64-bit datum, however this target's assembler spells it. `int64` is
# wasm's, and it is the first here that is not one of a machine assembler's
# historic names -- a reminder that this list is a dialect and not a standard,
# and that a target admitted without a matching arm reports every value as
# unfolded rather than as wrong (ADR-0383).
WIDE = re.compile(
    r"^\s*\.(?:quad|xword|8byte|dword|int64)\s+(?:0\s*\+\s*)?(-?\d+)")
# ...and the half of one, for the targets that have no 64-bit directive: a
# 32-bit machine writes an i64 constant as two of these, and which half comes
# first is the datalayout's `e`/`E`.
HALF = re.compile(
    r"^\s*\.(?:long|word|4byte|int32)\s+(?:0\s*\+\s*)?(-?\d+)")
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


# Claim 2's probe. Each row is a Pascal record holding a byte and one datum,
# and the LLVM struct that record must be laid out as. The compiler's own
# answer comes from `--dump-layout` -- the product feature ADR-0185 added,
# which reports exactly what RecordLayout, LlSize and LlAlign computed -- and
# LLVM's from folding a getelementptr over the struct. Six rows, because six
# is what ADR-0325 made vary: a pointer, an i64, a double, a complex, a set,
# and the two-pointer pair `tyProc` and `tySlice` are.
WORD_PROBE = [
    ("wptr",  "record c: char; v: ^integer end",  "{ i8, ptr }"),
    ("wi64",  "record c: char; v: int64 end",     "{ i8, i64 }"),
    ("wreal", "record c: char; v: real end",      "{ i8, double }"),
    ("wcplx", "record c: char; v: complex end",   "{ i8, <2 x double> }"),
    ("wset",  "record c: char; v: set of char end", "{ i8, i256 }"),
    ("wpair", "record a: ^integer; b: ^integer end", "{ ptr, ptr }"),
]


WPAIR = [n for n, _, _ in WORD_PROBE].index("wpair")


def compiler_layout(target):
    """What this compiler computed for the probe's records, from --dump-layout.

    Read out of the compiler rather than transcribed from aptypes.pas: what is
    being checked is the arithmetic, and a transcription would agree with
    itself. Returns {name: (size, align)}.
    """
    decls = "".join("     %s = %s;\n" % (n, d) for n, d, _ in WORD_PROBE)
    src = ("program w(output);\ntype\n" + decls +
           "var " + "; ".join("v%d: %s" % (i, n)
                              for i, (n, _, _) in enumerate(WORD_PROBE)) +
           ";\nbegin v0.c := 'x'; writeln(v0.c) end.\n")
    with tempfile.NamedTemporaryFile("w", suffix=".pas", delete=False) as f:
        f.write(src)
        path = f.name
    try:
        r = run([PASCALC, "--target=" + target, "--dump-layout", path,
                 "-o", os.devnull])
        if r.returncode != 0:
            die("the layout probe would not compile for %s:\n%s"
                % (target, r.stdout + r.stderr))
        got = {}
        for line in r.stdout.splitlines():
            m = RECORD.match(line)
            if m:
                got[m.group(1)] = (int(m.group(2)), int(m.group(3)))
        return got
    finally:
        os.unlink(path)


def llvm_layout(target, dl):
    """What LLVM lays the same six structs out as. {name: (size, align)}."""
    types, consts, names = [], [], []
    for i, (name, _, body) in enumerate(WORD_PROBE):
        tag = "%%w%d" % i
        types.append("%s = type %s" % (tag, body))
        # The size, and -- as an array of two -- the stride, whose difference
        # from the size is the tail padding and so gives the alignment.
        types.append("%sa = type [2 x %s]" % (tag, tag))
        consts.append("@%s_size = global i64 ptrtoint (ptr getelementptr "
                      "(%s, ptr null, i32 1) to i64)" % (name, tag))
        consts.append("@%s_f1 = global i64 ptrtoint (ptr getelementptr "
                      "(%s, ptr null, i32 0, i32 1) to i64)" % (name, tag))
        names += [name + "_size", name + "_f1"]
    vals = offsets_for(target, dl, types, consts)
    missing = [n for n in names if n not in vals]
    if missing:
        die("%s: the layout probe folded nothing for %s"
            % (target, ", ".join(missing)))
    out = {}
    for name, _, _ in WORD_PROBE:
        # Field 1's offset is the datum's alignment for the five `{ i8, X }`
        # rows; for the pair it is the pointer size, which is that row's
        # alignment too. Either way it is what the compiler must agree on.
        out[name] = (vals[name + "_size"], vals[name + "_f1"])
    return out


def check_words(target, dl):
    """Claim 2, for one target. Returns a list of disagreements."""
    mine, theirs = compiler_layout(target), llvm_layout(target, dl)
    bad = []
    for name, _, _ in WORD_PROBE:
        if name not in mine:
            die("%s: --dump-layout reported nothing for record %s"
                % (target, name))
        msize, malign = mine[name]
        lsize, lf1 = theirs[name]
        if msize != lsize:
            bad.append("%s: %s size -- the compiler says %d, LLVM lays it out "
                       "as %d" % (target, name, msize, lsize))
        # The compiler's alignment for the record is the datum's, which is
        # where LLVM put field 1 in the five padded rows.
        if name != "wpair" and malign != lf1:
            bad.append("%s: %s alignment -- the compiler says %d, LLVM puts "
                       "the field at %d" % (target, name, malign, lf1))
    return bad


def main():
    if not os.path.exists(PASCALC):
        die("no compiler at %s -- build first, or set PASCALC" % PASCALC)
    targets = admitted_targets()
    if len(targets) < 2:
        die("only one target is admitted (%s); nothing to compare, and a "
            "layout gate that compares one target asserts nothing"
            % ", ".join(targets))

    # **A target this machine's clang cannot answer for is not compared, and
    # the run says which** (ADR-0384) -- `setjmp-arity`'s rule, met here for
    # the same reason one release later: a gate that fails where it cannot
    # ask is one that reports about the machine. Two ways it cannot ask, and
    # they are different: no backend for the triple, and a *different idea* of
    # the triple's layout, which is what an older LLVM has for wasm32.
    layouts, absent, disagree, cannot = {}, [], [], []
    for t in targets:
        dl = datalayout_of(t)
        if dl is None:
            absent.append(t)
            continue
        mine = emitted_datalayout(t)
        if modelled(dl) != modelled(mine):
            disagree.append((t, dl.strip(), mine.strip()))
            continue
        # **Answering about a target and assembling for one are two
        # questions**, and macOS answers the first and not the second: its
        # clang states wasm32's datalayout and has no backend to emit for it,
        # so the probe assembled below died where this abstains. Asked with a
        # module of nothing, before any of the real work.
        probe = run([CLANG, "--target=" + t, "-S", "-o", os.devnull,
                     "-x", "ir", "-"], input=dl + "\n")
        if probe.returncode != 0:
            cannot.append(t)
            continue
        layouts[t] = dl
    targets = [t for t in targets if t in layouts]
    for t in absent:
        print("target-layout: %-24s not compared -- this clang has no backend "
              "for it" % t)
    for t in cannot:
        print("target-layout: %-24s not compared -- this clang states a "
              "layout for it and cannot assemble for it" % t)
    for t, theirs, mine in disagree:
        print("target-layout: %-24s not compared -- this clang states a "
              "different layout for it than the module does, so the two are "
              "not talking about one target. **That is a real difference and "
              "not only this gate's problem**: clang overrides the module's "
              "line with its own for the --target= it is given (ADR-0156), so "
              "on this machine a type whose alignment the two disagree about "
              "is laid out one way by the compiler and another by the "
              "assembler -- which is the ADR-0028 defect. What this target is "
              "supported against is the layout below on the `module` line" % t)
        print("           clang: " + theirs)
        print("          module: " + mine)
    if len(targets) < COMPARE_FLOOR:
        die("only %d of the admitted target(s) could be compared and the "
            "floor is %d -- a layout gate that abstains for almost everything "
            "asserts nothing (ADR-0282)" % (len(targets), COMPARE_FLOOR))

    # Claim 2 first: it is cheap, it is the half ADR-0325 introduced, and a
    # target whose two varying numbers are wrong would make claim 1's classes
    # wrong as well.
    bad2 = []
    for t in targets:
        bad2 += check_words(t, layouts[t])
    if bad2:
        sys.stderr.write(
            "target-layout: the compiler's own layout arithmetic disagrees "
            "with LLVM.\nPtrSize, WordAlign and WideAlign in "
            "selfhost/aptypes.pas are what vary per target\n(ADR-0325, "
            "ADR-0383); LlSize and LlAlign are what read them.\n")
        for line in bad2:
            sys.stderr.write("  " + line + "\n")
        sys.exit(1)

    # Claim 1: within a word-size class, every frame lays out identically.
    types, consts, names = {}, {}, {}
    for t in targets:
        types[t], consts[t], names[t] = build_module(SOURCES, t)
        if len(names[t]) < MIN_OFFSETS:
            die("%s: only %d offsets to compare, below the floor of %d -- the "
                "frame extraction reached almost nothing"
                % (t, len(names[t]), MIN_OFFSETS))

    measured = {}
    for t in targets:
        vals = offsets_for(t, layouts[t], types[t], consts[t])
        missing = [n for n in names[t] if n not in vals]
        if missing:
            die("%s: %d of %d constants were not folded to a number "
                "(first: %s)" % (t, len(missing), len(names[t]), missing[0]))
        measured[t] = vals

    # **The class is every answer the compiler's arithmetic gives for this
    # target**, and it was the pointer size until wasm32 was admitted
    # (ADR-0383). Two targets can share a word size and lay a frame out
    # differently: wasm32 is ILP32 like i386 and aligns an i64 to eight where
    # i386 aligns one to four, so `record c: char; v: int64 end` is 16 bytes
    # on one and 12 on the other -- and each is *right*, which claim 2 has
    # just shown. Classing by the word size put them together and reported
    # 337 correct offsets as a divergence.
    #
    # So the key is the six-shape signature rather than one number of it. It
    # is derived from the compiler on this run, so a seventh number coming to
    # vary splits the classes here without this file being edited -- which is
    # the same property that makes the target list the compiler's own
    # refusal. What claim 1 then says is exact: **targets whose layout
    # arithmetic is identical must lay every frame out identically**, which
    # is the statement `LlSize and LlAlign answer with one number` was
    # standing in for.
    klass = {}
    for t in targets:
        mine = compiler_layout(t)
        sig = tuple(mine[n] for n, _, _ in WORD_PROBE)
        klass.setdefault(sig, []).append(t)

    bad = []
    for sig in sorted(klass):
        group = klass[sig]
        base = group[0]
        for t in group[1:]:
            shared = [n for n in names[base] if n in names[t]]
            if len(shared) < MIN_OFFSETS:
                die("%s and %s share only %d offsets, below the floor of %d"
                    % (base, t, len(shared), MIN_OFFSETS))
            for n in shared:
                if measured[t][n] != measured[base][n]:
                    bad.append((n, base, measured[base][n],
                                t, measured[t][n]))

    if bad:
        sys.stderr.write(
            "target-layout: %d offsets differ between targets whose layout "
            "arithmetic is identical.\nThese targets agree on the size and "
            "alignment of every shape in the probe, so a frame that differs\n"
            "is wrong for at least one of them -- see ADR-0028.\n" % len(bad))
        for n, a, av, b, bv in bad[:20]:
            sys.stderr.write("  %-24s %s=%d  %s=%d\n" % (n, a, av, b, bv))
        if len(bad) > 20:
            sys.stderr.write("  ... and %d more\n" % (len(bad) - 20))
        sys.exit(1)

    print("target-layout: the compiler's size and alignment agree with LLVM "
          "for %d targets over %d shapes" % (len(targets), len(WORD_PROBE)))
    for sig in sorted(klass):
        group = klass[sig]
        # The pointer size names the class for a reader; the *key* is the
        # whole signature, and saying only the width would now be the mistake
        # this classing was changed to stop making.
        width = sig[WPAIR][0] // 2 * 8
        if len(group) > 1:
            print("target-layout: %d offsets identical across %s (%d-bit, and "
                  "one layout arithmetic)"
                  % (len(names[group[0]]), ", ".join(group), width))
        else:
            print("target-layout: %s lays out like no other admitted target "
                  "(%d-bit), so its frames are compared with nothing -- the "
                  "check above is what covers it" % (group[0], width))


if __name__ == "__main__":
    main()
