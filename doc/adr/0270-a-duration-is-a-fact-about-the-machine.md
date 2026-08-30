# 270. A duration is a fact about the machine, so what is committed is a proportion

Date: 2026-08-31

## Status

Accepted, 2026-08-31.

## Context

Nothing in this tree had ever profiled the compiler. `performance-profile` is a
skill and there is no evidence it was run; `doc/roadmap.md`'s tooling chapter
carried three numbers taken sideways while building the language server, and
when they were re-measured for this record **every one of them had moved**.

The chapter also said what was missing before any profile: *the self-hosting
build is the natural benchmark and no committed number says how long it takes,
so there is nothing for a regression to fail against.* Twenty-five gates here
can say the compiler is wrong. None can say it got slower.

That is not a hypothetical risk in a compiler whose hot loops are written by
hand. `LookupKeyword` is a linear scan of forty-five word-symbols with an inner
character loop, run for every identifier; the parser bounds its own depth by
counting; Sema's schema intern table is a list. Any of them could acquire
another factor of *n* in a change that looks local and passes every gate here.

## Decision

`tests/checks/benchmark.py`, a `ctest` case.

**It commits proportions and not milliseconds.** A baseline in milliseconds is
a fact about the machine that took it: a slower machine then fails a gate it
should pass, and the only threshold that survives that -- three times, five
times -- catches a catastrophe and nothing else. What is committed instead is
six numbers, each divided by something measured in the *same run*:

- four **stage shares** of one compile of `selfhost/apfront.pas`, the largest
  component. The stages are separated by dump flags rather than by a profiler,
  because each `--dump-*` stops at the stage it names (ADR-0025):
  `--dump-tokens` is lexing, `--dump-ast` adds parsing, `--dump-sema` adds
  Sema, and no flag adds the code generator. Four subtractions and no tooling.
- two **component scales**, `apfront.pas` and `compiler.pas` against
  `aptypes.pas`, which catch work growing faster than the source does.

**The first design was a ratio to a whole compile and it did not work.** The
denominator was `aptypes.pas` compiled whole, which runs the code generator
like everything else -- so a mutation making `EmitStmt` do 4000 units of wasted
arithmetic per statement slowed the numerator and the denominator together, and
every ratio stayed inside tolerance. The gate passed on a compiler measurably
slower. That is recorded in `shares()` rather than deleted, because the
mistake is the reason the shape is what it is.

**The tolerance is per proportion**, from the measured spread of six
consecutive runs: 1.1% for the code generator's share, 1.8% for the lexer's,
2.1% for Sema's, 6.9% for the two scales, 9.4% for the parser's -- the parser
being a 19 ms difference between two 100 ms measurements, the one number small
enough for noise to matter. So it is 15%, 15%, 15%, 20%, 20% and 30%
respectively. A single figure would have had to be the loosest of them, and 25%
lets a code generator made a fifth slower through.

**A failure is confirmed before it is reported.** Everything here is a
duration, and a duration is the one measurement in this tree a machine can get
wrong by itself. The whole measurement is taken a second time and the finding
has to survive; a regression reproduces and a scheduler hiccup does not, and
the cost is paid only when something already looks wrong. `RUN_SERIAL`, for
the same reason: under `ctest -j` it would be measuring the other jobs.

## Consequences

**The first profile of this compiler, and it is a surprise.** Over
`apfront.pas` -- 24 206 lines, plus the 4 295 of ApTypes its translation reads:

| stage | ms | share |
| --- | --- | --- |
| lexing | 99 | 26.2% |
| parsing | 19 | 5.1% |
| Sema | 90 | 23.9% |
| the code generator | 169 | 44.9% |

**The lexer costs five times the parser.** Nobody would have guessed that, and
it is the concrete lead this record produces: `LookupKeyword` scans all
forty-five word-symbols for every identifier, comparing character by character
after trimming the padding off the table entry each time. That is not a defect
and is not fixed here -- it is a measurement, which is what was missing.

The code generator being 44% of the compile is the other half, and it is where
`--dump-uses` gets its cost: the language server's hover stops after Sema and
still pays 199 ms of a 377 ms compile.

**What it catches, measured rather than claimed.** The 4000-unit mutation moves
the code generator's share from 0.449 to 0.555 and the gate names the stage;
1500 units moves it to about 0.48 and passes. The threshold is a stage made
roughly a third slower.

**What it cannot see** is a change that slows every stage of every component in
the same proportion -- a pool lookup they all make, a slower `Peek`. Both
denominators slow down with it. The milliseconds are recorded beside the
proportions with the machine that took them, for a reader; they are not
compared, because comparing them is the design that does not work.
`doc/sop.md` §7 carries the row.

**It costs 5.9 seconds** and the suite is 262. That is the second-cheapest of
the sixteen gates that make up 234 seconds of it.

The alternative rejected: recording milliseconds with a 3x threshold and a
note that it is machine-dependent. It is simpler, it needs no denominator, and
it would have caught the mutation above -- but it goes red on any slow machine
and green on a 2x regression on a fast one, which is a gate whose verdict
depends on where it ran.
