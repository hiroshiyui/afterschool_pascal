# 275. Input nobody wrote on purpose

Date: 2026-08-31

## Status

Accepted, 2026-08-31.

## Context

Every corpus in this repository is hand-written. `tests/` is programs someone
wrote to pin a clause; `selfhost/torture.pas` and `selfhost/badparse/` are
error paths someone thought of; `tests/spec/` starts from a clause and asks
what the compiler does about it. Three oracles were not written here — Unicode's
conformance files, Free Pascal, and the BSI suite until ADR-0232 retired it —
and all three are still *programs and data someone composed*.

So the claim **this compiler does not crash on hostile input** was made by
nothing. `doc/roadmap.md` had carried it since ADR-0261 closed the sanitizer
row:

> **Fuzzing is still open**, and is now the whole of what this bullet asks
> for: a hand-written lexer and parser over **fixed buffers** (ADR-0012) is
> the canonical target, and `selfhost/torture.pas` and `selfhost/badparse/`
> are hand-written corpora — ADR-0067's *a claim no test names is a claim
> nothing checks*, applied to crash-resistance instead of to conformance.

The target is unusually well-shaped for it. ADR-0012 sizes the token array,
the string pool and the identifier buffer as constants; ADR-0020 bounds the
tree at 1000 levels and makes the operator loops count their own iterations
toward it; and ADR-0023's whole parser discipline is that every production and
every loop tests `aborted`, because Pascal has no exceptions. Each of those is
a claim about what happens at a limit, and a limit is what a generator reaches
and a person does not.

## Decision

`tests/checks/fuzz.py`, a `ctest` case. **Three families, and the split is
what each can prove.**

**Truncation.** Every prefix of a real source, byte by byte. Exhaustive rather
than random along one axis: it puts the parser at end-of-file in every state a
source can reach, which is the shape a missing `aborted` test takes.

**The bounds.** One generated input per fixed buffer and per depth limit, each
asserting the **message** and not merely survival — because ADR-0012's claim is
not that a full buffer is survivable but that it is a *diagnostic*. Ten of
them: four kinds of nesting, the token array, the string pool, the identifier
and literal lengths, and the two unterminated lexemes.

**Mutation.** A fixed number of deterministic mutations of the corpus, one to
three edits each so that a mutant starts from a real program and arrives
somewhere deep with it.

**The seed is fixed, and that is the decision the rest hangs on.** What runs
under `ctest` is a *regression suite of hostile inputs*, not a search: 3128
inputs, 5.3 s, the same ones every time. `--long N` is the search and is run by
hand. A fuzzer that fails randomly on someone else's commit is a fuzzer people
learn to ignore, and this repository's gates are all deterministic for that
reason — `benchmark` is the one that measures a duration and it confirms a
failure by a second measurement before reporting it (ADR-0270).

A mutant may loop, and a compiler that loops writes IR while it does, so every
child runs under `RLIMIT_FSIZE`, `RLIMIT_AS` and a timeout.

## Consequences

**It found no crash.** 3128 inputs in the suite and 41 628 in a campaign: no
signal, no trap in the compiler's own runtime, nothing unfinished. Every fixed
buffer and every depth limit answers with the diagnostic it promises. That is
the result — the claim is now made by something — and it is worth stating that
a first fuzzing run finding nothing is the unusual outcome.

**It found the argument that was standing in for a case.** Two messages,
`too many tokens` and `out of string space`, were *excluded* from
`diagnostic-coverage` by a regex whose comment read: "the two capacity limits
are not diagnostics about a program being compiled and have no golden by
design". Both carry a file, a line and a column, and the compiler writes them
about a program it was handed — `p.pas:75001:3: error: too many tokens: this
compiler accepts 300000`. The reason neither had a golden is that no case had
ever reached one. Reaching them takes 300 KB of semicolons and 1.2 MB of
distinct identifiers, neither worth committing, so `fuzz.py` generates the
input and `tests/checks/fuzz_bounds.err` is the golden that names the message
— an ordinary `.err`, because `diagnostic_coverage.py` globs `tests/**/*.err`
and a message named in one is a message named by a golden. The gate now counts
726 messages where it counted 724.

That file and `fuzz.py`'s own table are checked against each other in both
directions, so neither can drift; `--write-golden` regenerates it.

**It found a quadratic in Sema.** 60 000 variable declarations in one block did
not finish in 20 seconds, and the curve is exact — 1000 declarations 0.03 s,
2000 0.06, 4000 0.24, 8000 1.00, 16 000 3.49, 32 000 14.31. `Declare` asks
`LookupInScope`, which is a linear scan of the scope's entries, so declaring
*n* names in one block costs *n²* pool comparisons. It is bounded rather than
unbounded — `tokMax` admits about 75 000 such declarations, so the worst case
is roughly 80 seconds and then a diagnostic — and it is invisible to real code,
this compiler's largest block having a few dozen locals. It is **not fixed
here**: it is a performance property and not a crash, the fix is a second
structure beside the scope stack, and a change to how Sema resolves names in a
compiler that must self-host deserves its own measurement. `doc/sop.md` §7
carries the row.

**Four mutations, three killed by the family that should kill them.** Raising
the depth bound a thousandfold is caught by the bounds family, on all four
nesting inputs at once. Removing `StrAppend`'s `s.len < strMax` guard — a
write past a fixed array — is caught by the mutation family, four inputs
trapping with `runtime error: value out of range (strlen)`, and by the bounds
family too. Making `Bail` not set `aborted` is caught by the truncation
family, 10 prefixes of 1618, which is the family's own kill and the reason it
is worth its 1.6 s.

The fourth is the honest one: dropping `and not aborted` from the variant-list
loop was caught by **nothing** — not 1618 truncations, not 40 000 mutants, and
not the 787-case suite either. So it is a guard nothing here can distinguish,
which is a fact about that guard and not a gap in this gate.

The suite gains 5.3 seconds. `doc/roadmap.md` says sixteen cases are 234 of
its 262 seconds, so this is not one of them.

## Alternatives rejected

**libFuzzer or AFL++.** Both want an entry point to drive in-process, and the
compiler is a Pascal program that reads a file — there is no entry point to
write without a C shim around a language that has no way to be called from
C. Black-box mode gives up coverage guidance, which is the only
thing they were wanted for, and costs a dependency this repository does not
have. `cmake`, `make` and `clang` are the whole of what it needs, and
`tests/spec/run.py` is a Gherkin subset written by hand for the same reason.

**Coverage-guided mutation, using `pascalc --coverage`.** The compiler can
instrument itself, so a guided loop is buildable — and ADR-0274 has just made
its branch coverage readable. It would be the right second version. It is not
the first one, because a guided fuzzer that finds nothing is indistinguishable
from a broken guided fuzzer, and a blind one that finds nothing over 41 628
inputs at least says what it did.

**A time budget instead of a fixed count.** A duration is a fact about the
machine that took it (ADR-0270), so a 30-second budget is a different test on
every machine and a different test on the same machine under load. The count
is the same everywhere and the seed makes the inputs the same too.

**Running the compiled mutants.** A mutant that compiles at all is rare and one
that compiles into a program worth running is rarer, and `sanitizers` already
runs the whole corpus under ASan, UBSan and LSan (ADR-0261). What this adds is
about the *front end*, which is where the fixed buffers are.

**Committing the two capacity-limit sources as ordinary cases.** 1.5 MB of
generated text in `tests/`, regenerated by hand whenever `tokMax` or `poolMax`
moves, to assert what nine lines of generator assert.
