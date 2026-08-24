# 183. The heap balance is the oracle that reads no output

Date: 2026-08-24

## Status

Accepted.

## Context

Every oracle in this repository reads what a program **prints**. A golden
compares its output, a `.err` compares its diagnostics, `tests/dumps/` compares
what the compiler wrote, `difftest` compares two front ends' answers, the BSI
catalogue records a pass or a fail, `verify/` proves a lowering against a
model, and `tests/spec/` runs a scenario and reads what came out.

A leak prints nothing.

Two records in one day turned on exactly that. ADR-0181 found that a handle
inside a heap record was never released, because "released when the variable
holding it dies" reaches nothing created by `new`; the measurement was
`ulimit -n 64` and a counting loop, run once, by hand. ADR-0182's abandoned
chain was 5.8 MB against 58 MB, taken the same way. Both defects had been
reachable for as long as the constructs existed, with the suite green
throughout, and after each fix nothing was left watching.

`doc/sop.md` §7 carried the gap in the terms above: there is no
memory-accounting oracle here at all, and the `-fsanitize` runs of
`security-audit` are the nearest thing and are not a gate.

## Decision

**The runtime counts what `new` created and `dispose` gave back, and a gate
compares the balance of every heap-using case against a catalogue.**

`pas_new` and `pas_dispose` keep a tally; when `$PASHEAP_BALANCE` is set, an
`atexit` hook writes `new=… dispose=… live=…` to the file it names.
`tests/checks/heap_balance.py` runs the corpus with that variable set and
compares each `live` against `tests/checks/heap_balance.txt`.

Four things decided.

**A count, not a byte total.** `dispose` is handed a pointer and no size, and a
runtime header carrying one would move every address the compiler computes. The
count is the exact question anyway: one `new` unmatched is one variable nobody
gave back, whatever it weighs — and it is *exact*, where a byte total or a
peak-RSS reading is a statistic. The gate catches a two-variable leak, which no
RSS measurement ever would.

**A nonzero balance is not an error.** No standard obliges a program to dispose
what it created, and a program about to end has an operating system to do it.
Seven of the 29 cases legitimately end with something outstanding. So this is a
catalogue and not a rule, and it fails in **both** directions —
`tests/bsi/expected.tsv`'s and `verify/`'s rule: a program that starts leaking
is as loud as one that stops.

**`--coverage`'s discipline for the cost.** Counting is two increments and
unconditional; the `atexit` hook is armed on the first `new` and only when the
variable is set. A program not being measured pays one `getenv` and nothing
else — ADR-0104's shape, for ADR-0104's reason.

**The heap-using corpus, and the filter is itself checked.** A case counts when
its own source or a component it lists calls `new`; 29 do. Sweeping the other
six hundred would cost minutes to learn that a program with no heap has an
empty one. A catalogued case the filter stops selecting is a failure, so the
filter cannot quietly shrink — which is `difftest`'s corpus-size check applied
to a different question.

## Consequences

3.8 seconds, and it runs with every `ctest`.

**The demonstration is mutation 3**, and it is what justifies the gate. Make
`dispose` set the pointer to `nil` and never free — a leak on every explicit
`dispose` in the corpus. The whole suite passes: **735 of 735 cases and 230 of
230 scenarios**, with `lib_map` leaking eight variables a run and eighteen
other cases leaking too. Only `heap-balance` fails, and it names every one of
them.

**A claim of mine was too strong and is corrected here.** Mutation 2 — `new`
ceasing to be a release point (ADR-0182's rule) — *is* caught by the existing
suite: `spec-dialect_owned` reads a file back and sees the unflushed stream,
and `line-coverage` sees the arm go unreached. So the case for this gate is not
that it sees what nothing else can. It is **coverage**: the three cases with a
leak observation have one because someone wrote a stream into them on purpose,
for a mutation they had already thought of, and nothing generalises that to the
twenty-six that nobody instrumented. Mutation 3 is the shape of a defect nobody
thought of, and it is invisible to everything else here.

**The first run of the gate measured the wrong program.** Every case reported
hundreds of outstanding variables. Those were the *compiler's*: `pascalc` is
itself a Pascal program on this runtime, it inherited `PASHEAP_BALANCE` from
the harness, and it appended its own allocations to the same file.
`tests/run_test.sh` now takes the variable out of the environment and restores
it only around the program under test. That scoping is correct regardless of
this gate, and the comment there records why it is not obvious.

It also settles a question nobody had asked: **the compiler disposes almost
nothing**, allocating for the length of a translation and letting the process
end. That is a reasonable design for a compiler and is not a defect; it is
recorded here because the number was startling before it was explained.

## What this does not do

**It does not count files or handles.** Those are the other two affine kinds,
and a `fopen` without an `fclose` is invisible to this. The runtime already
keeps both live lists (`pas_open_files`, `pas_live_handles`) and could report
their length at exit, but every program legitimately ends with `output` open,
so the numbers would need the same catalogue treatment and a reason to believe
the baseline. Left for the increment that wants it.

**It does not see a leak inside one run.** The count is taken at exit, so a
program that allocates a million variables and disposes them all at the end has
a balance of zero and a peak nobody measures. ADR-0181's original defect was of
exactly that shape — descriptors exhausted at iteration 62 of a loop that would
have balanced eventually — and this gate would have caught it only because the
loop never disposed at all.

**It does not run the whole corpus.** Six hundred cases have no `new` in them
and are not swept.

**It is not a sanitiser.** It says a variable was not given back; it says
nothing about a use after free, an overrun, or an uninitialised read.
`security-audit`'s `-fsanitize` runs remain the tool for those and remain not a
gate.

## Alternatives rejected

**LeakSanitizer over the corpus.** Free instrumentation, catches C-level leaks
this cannot see, and rejected for a blind spot that matters here: LSan reports
*unreachable* blocks, and a level-0 activation record in this compiler is a
**global**, so a leak still pointed at by a program-level variable is "still
reachable" and goes unreported. That is precisely the shape of ADR-0181's
defect. A counter has no notion of reachability and so has no such gap.

**Peak RSS with a ratchet.** What I measured by hand for ADR-0182, and it works
only for enormous leaks: 5.8 MB against 58 MB was visible, two variables never
would be. It is also machine-dependent and allocator-dependent, which is a poor
foundation for a gate that must fail in both directions.

**Making a nonzero balance an error.** It would be a rule rather than a
catalogue, and it is not what any standard says: a program is entitled to end
with its heap outstanding. It would also have required editing 7 conforming
corpus programs to satisfy a gate, which is the tail wagging the dog — and
`langspec-audit` exists because tests edited to satisfy a check are how a
misreading becomes permanent.
