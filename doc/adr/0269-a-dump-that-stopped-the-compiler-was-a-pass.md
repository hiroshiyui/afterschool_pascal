# 269. A dump that stopped the compiler was a pass

Date: 2026-08-31

## Status

Accepted, 2026-08-31.

## Context

`tests/checks/coverage.py` drives the whole corpus through the compiler twice —
once as an ordinary translation and once again under `--dump-all` — and reads
one thing back: which addresses the run reached. It never read what the child
*did*.

`sweep()` called `subprocess.run` and threw the result away. So a compiler that
**stopped** part-way through was indistinguishable from one that finished: it
wrote a short dump, contributed the addresses it had reached before dying, and
was counted as one more source swept. Nothing in this tree would say otherwise,
because every other oracle here compares what a *program* printed and a dump is
what the *compiler* printed — and the dump corpus, `tests/dumps/`, covers the
shapes it has cases for and no others.

That is not hypothetical. `--dump-sema` crashed on **every program declaring a
fallible-type** for three days and 714 green cases. It surfaced only because a
new branch in the same walker went unreached and `line-coverage` asked why —
which is to say it was found by a gate answering a different question, by luck.

`doc/sop.md` §7 has carried the row since ADR-0176, and the row named its own
fix: *the sweep could read the child's status, or look for `runtime error:` in
what a dump wrote, and name the source.* A row that names its own closing
condition is one of the three staleness shapes ADR-0197 warns about, because
the person who meets that condition is working on something else. It sat for
five records.

## Decision

`sweep()` takes an optional list and appends to it every invocation the
compiler did not survive; `procedure-coverage` passes one and fails on it.

**A crash is not a compile failure, and the exit status alone cannot tell them
apart.** A third of this corpus exists to be rejected — `selfhost/badparse/`,
`selfhost/badsema/`, `selfhost/torture.pas` — and a rejection exits 1. So does
`pas_runtime_error`. Two signals separate them:

- a **negative return code**, which is a signal: SIGSEGV, SIGABRT, a stack
  exhausted because ADR-0020's depth bound was wrong for some shape;
- `runtime error:` at the **start of a line of standard error**, which is the
  runtime's own wording on the runtime's own stream. The compiler's diagnostics
  go to `output` — no standard Pascal program has a second stream — so standard
  error carries nothing else.

Matching that text *anywhere* would have matched a dump of the compiler's own
source, whose emitter carries the literal and prints it to standard output.
`variant_check.sh` met exactly this on its first run and its comment says so;
this is the same trap avoided the same way.

The check runs **before** the coverage arithmetic and before `--report`. A
compiler that stopped part-way through the corpus reached fewer statements than
it should have, so every number computed after it is measured against a run
that did not finish — reporting the coverage first would be reporting a figure
already known to be wrong.

**A timeout stays a warning.** It is the one signal a loaded machine can
produce by itself, and 300 seconds on a corpus source is already far outside
anything this compiler does. Making it a failure would buy a rare shape at the
cost of a gate that goes red on a busy CI runner, which is how a gate becomes
something people re-run rather than read.

**It is checked in one place and not two.** `line_coverage.py` has a `sweep()`
of its own and runs the same corpus once per instrumented program-component;
checking there would report every crashing source three times for one defect.
The corpus is the same corpus, so once is enough.

## Consequences

The gate refuses to pass by asking nothing. Mutating `Tokenize` in
`selfhost/apfront.pas` to store 3 into a `1..2` — one line, reached by every
invocation — makes it report **1426 of 1435 invocations stopped the compiler**
and exit 1, where before the mutation the suite was green: `procedure-coverage`
passed, `line-coverage` passed, and 774 ctest cases passed, because the corpus
was being rejected in a way nothing was reading.

The nine that survived are the invocations that reach no lexer at all —
`--version`, `-h`, and the argument-error cases — which is the right answer and
a useful check on the instrument.

**The subject is the instrumented compiler**, which is the same program with a
counter per statement (ADR-0104). A trap in it is a trap in the compiler; the
one class this cannot see is a defect the instrumentation itself repairs, and
none is known.

**What it still does not see** is the *content* of a dump. A walker that writes
the wrong thing without stopping is caught by `tests/dumps/`'s goldens for the
shapes those cases have and by nothing else — which is the same sentence
ADR-0103 wrote about the dump corpus, unchanged. This closes "did the compiler
survive", not "was the dump right".

`doc/sop.md` §7's row closes with this record, and the roadmap's tooling
chapter loses half of one bullet: of the three blind spots it listed, the
sanitizer one closed with ADR-0261 and this is the second. The one that
remains is that a **branch** is invisible to `line-coverage`, which counts
statements.
