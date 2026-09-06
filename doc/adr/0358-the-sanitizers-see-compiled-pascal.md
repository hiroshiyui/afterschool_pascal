# ADR-0358: The sanitizers see compiled Pascal

Date: 2026-09-07

## Status

Accepted. Changes what every compilation emits — one attribute group and a
reference to it on every function — and makes `tests/checks/sanitize.sh`
refuse to sweep in its two instrumenting modes until a probe the sanitizer
must report has been reported. Closes the `doc/sop.md` §7 row ADR-0342 opened
and ADR-0353 half-closed.

## Context

ADR-0342's audit found the largest thing in its record without reading a
clause: clang's AddressSanitizer pass instruments only a function carrying
`sanitize_address`, ThreadSanitizer's only one carrying `sanitize_thread`,
and this emitter wrote neither. So `AFTERSCHOOL_PASCAL_CFLAGS=-fsanitize=address`
reached the compilation of every `.ll` and changed nothing about a program's
own loads and stores; `new(p); q := p; dispose(p); q^ := 5` printed 5 under a
fully ASan-linked binary; and every sentence of the form *ASan reports
nothing* ever written about a Pascal program here was about the runtime's C.
The record measured the fix — one attribute, and the probe reports the
use-after-free with a stack trace — and did not take it, "being a change to
what every compilation emits and one that would redden the gate over whatever
the corpus turns out to contain". ADR-0353 brought Valgrind, which needs no
attribute, and covered the *class* at 170 seconds; the register's row said
the speed was not covered and the decision had still never been put.

Two things made it a decision worth putting today. The cost that was feared
is measurable, and no one had measured it. And ThreadSanitizer has exactly
the same shape: `thread-sanitizer` swept eleven concurrent programs and could
see a race in `pas_chan_send` and not one in a task, so AP 6.7.8.2 NOTE 3's
global reached through a procedure — which ADR-0342 measured losing two
thirds of its increments — was a wrong number and never a report.

## Decision

**Every function the emitter defines carries `#1`, and
`attributes #1 = { sanitize_address sanitize_thread }` is written beside
`#0`'s `returns_twice`.** Seven writers produce a `define` here — an ordinary
routine, `@main`, a module's initialiser and its finaliser, a task's wrapper, a
deferred-statement runner and an owned-value release — and all seven carry it.
It is unconditional: the attributes are inert until clang runs the pass they
name, so a compilation that never asked for a sanitizer emits four more
characters per function and one more line, and behaves as it did.

**The harness proves its instrument before it sweeps.** In `address` mode
`sanitize.sh` compiles a use-after-free through the same driver, the same
compiler and the same second runtime every case below it gets, runs it, and
requires `ERROR: AddressSanitizer: heap-use-after-free`; in `thread` mode it
compiles two tasks incrementing a global through a procedure and requires
`WARNING: ThreadSanitizer: data race`. A run without the line fails and says
what it means: the emitted functions carry no attribute and every "clean"
below would be a program the tool was never asked about. This is the floor's
argument one step earlier — a run that reaches nothing prints the same tally
as a clean one, and so does a run whose instrument is off — and it is how the
gate can fail, which a harness change has to be able to show.

## Consequences

**The measurement.** With compiled Pascal instrumented, the corpus is 377
clean under ASan, UBSan and LSan in 81 seconds and the eleven concurrent
programs are clean under TSan in 8; the probe reports under both; and a
compiler built from the commit before this one fails the probe step in both
modes. The cost the earlier record priced was nothing.

**What the gates are oracles for, from today.** `sanitizers` asks whether a
*program* survives the suite, its own loads and stores included, and the
runtime's C as before. `thread-sanitizer` sees a race in a task. Valgrind
stays and is the complement, not the alternative: it instruments nothing, so
it needs no cooperation from the emitter and would catch this attribute going
missing by other means; it sees an uninitialised read, which ASan does not;
and it does not see a race. `valgrind-corpus` still sets the wall clock.

**Every emitted module changes.** The stage-2/stage-3 fixed point and
`llc-second-backend` compare a compiler's output with its own and are
indifferent; `verify/` models no attribute, and this commit carries
`Model-unchanged:` saying so. The committed seed does not change until a
release refreshes it, and a seed-built stage 1 emits the attribute the moment
it is built from this source, which is what ADR-0085's arrangement is for.

**A mutation and the case that kills it.** Removing the attributes line puts
the probe back to printing 5, and the `sanitizers` gate fails at its probe
step before sweeping anything; the catalogue entry names that gate.

## What this does not do

It does not add `sanitize_memory`; MemorySanitizer needs every linked object
instrumented, libc included, and nothing here builds that.

It does not retire `valgrind-corpus`, for the three reasons above.

It does not change what the runtime's C is compiled with: `-fsanitize` still
reaches it through the same flag, and the second `libpasrt.a` is built as it
was.

It does not instrument the compiler's own build. `build/bin/pascalc` emits the
attribute and is not compiled with a sanitizer; a sanitized compiler is
`AFTERSCHOOL_PASCAL_CFLAGS` at a build of `selfhost/compiler.pas`, as before,
and now means what it says.

## Alternatives considered

- **A `--sanitize` flag on the compiler**, emitting the attribute on request.
  A second thing for every harness and every user to remember to pass, for a
  line that is inert without the clang flag they already pass.
- **Attribute the routines and not `main`.** The first measurement here did
  exactly that by accident, and the probe — a program with no routines —
  printed 5 under it. A sweep clean of a class half-instrumented is the row
  this record closes, in a new shape.
- **Leave it to Valgrind.** The class was covered; the speed was not, and a
  race never was.
