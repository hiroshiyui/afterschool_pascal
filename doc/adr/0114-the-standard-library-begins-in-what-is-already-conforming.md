# ADR-0114: The standard library begins in what is already conforming

## Status

Accepted. First increment of the goal ADR-0109 set; decides nothing about the
dialect mode, the memory-safety model, the text model or the foreign-function
interface, all of which stay open.

## Context

ADR-0109 made the long-term goal a practical Pascal with a standard core library
for networking, internationalisation, concurrency and memory safety, as a third
`--std` beside the two conformance modes. `doc/roadmap.md` then put a
foreign-function interface first, "not because it is the most interesting but
because the rest is blocked on it".

That ordering is right about sockets, clocks and locales and wrong as a
statement about the library as a whole. A library has an inward-facing half that
is blocked on nothing: sorting, searching, string operations, integer arithmetic
written to survive a compiler that traps on overflow. Building that half first
buys something the FFI design cannot otherwise have — evidence about what the
module and import machinery actually costs a caller, gathered before a type
mapping is committed to it.

What decided the shape of this increment was **probing rather than reasoning**,
which is this project's own rule (ADR-0067) and it paid immediately. Five
assumptions about writing a library in this language were tested by compiling
one, and three were wrong.

## Decision

**The library is ordinary Extended Pascal, in `lib/`, imported by path, and the
compiler is not changed at all.**

Four choices, each the cheapest thing that could work:

- **`--std=extended`, not a new mode.** A library module is a §6.11
  module-declaration and a §6.13 program-component; both are implemented
  (ADR-0053, ADR-0079). Importing one changes nothing about what either
  conformance mode *accepts*, so ADR-0109's promise that the two stay exactly as
  they are is kept by construction rather than by care. The third mode is not
  needed until a feature needs it, and none of these did.
- **`lib/` at the top level**, not under `tests/`. The library is a product
  artefact and the corpus is not; putting it in `tests/extended/components/`
  would have bought difftest coverage by filing the product as a test.
- **Imported by path**, through the `--import` and `.components` mechanism that
  already exists. No search path, no install target, no resolution by name.
- **Three modules**, chosen so that between them they exercise every shape a
  library module can have: exported constants, types, functions and procedures;
  a schema exported and discriminated by the caller; procedural parameters;
  module-private state with an initialization-part.

### What the probes found, and what each forced

These are the three that were wrong, and each is now an API convention rather
than a discovery waiting to be made again.

- **A variable-string may not be a value parameter**, so a read-only string
  parameter is `protected s: string` — the bare schema-name, which is a
  schematic formal and therefore travels as an address and a capacity
  (ADR-0040). ADR-0052 recorded the refusal and its reason: §6.4.6 pads or
  refuses by length, the actual may be a literal or a string of another
  capacity, and a conversion needs somewhere to build its result.

  The consequence for a *caller* is the thing that was not previously written
  down anywhere: **an argument must be a string variable.** Neither a literal nor
  another function's result is a variable produced from the schema, so
  `StartsWith(s, 'Hello')` and `Upper(Reverse(s))` do not compile, and every
  call site names an intermediate. This is the largest single obstacle between
  this library and a comfortable one, and it is a *conformance* defect rather
  than a dialect question — which makes fixing it the highest-value language
  work this increment identified.

- **A parameter group naming a schema gives its names one type** (ADR-0040), so
  `protected s, prefix: string` forces two arguments to the same capacity and
  the two must be declared as separate groups. Read the record and this follows;
  it still surprised, because the grouping reads like a convenience.

- **A `forward`-declared function cannot use a result-variable-specification.**
  §6.11.1 makes a heading in a module-heading a `forward` under another name, so
  *every* exported function is one — and the result variable's identifier is not
  visible in the body, while restating it is refused as *the parameters of 'f'
  were already given in its forward declaration*. Since §6.8.2.2 makes every
  read of the function identifier a recursive call, `Upper := Upper + c` is a
  recursion and the other way to accumulate is unavailable.

  So an exported function **accumulates into a local and assigns its identifier
  once**. That is a clean workaround and it is not obviously the whole story:
  whether the standard intends the result variable to be visible in a
  `forward`-declared body is a reading this record does not settle, and it is
  filed as the first question for `langspec-audit` to take up. It is recorded in
  `doc/sop.md` §7 rather than fixed here, because a library increment is the
  wrong change to carry a Sema fix.

Two assumptions that held: a schematic formal plus a functional parameter gives
one compiled sort body serving every extent, and a module's private state is a
global in the emitted IR (ADR-0053) so a generator can keep a seed.

### No generics, and the shape that answers it

Schemata parameterise a type by a *value*, not by another type, so `list of T`
cannot be said and a container is per-element-type. Sorting does not need to be:
`SortIndexed` takes `less(i, j)` and `swap(i, j)` over `1..n` and never sees an
element, so the caller's two nested routines close over whatever the elements
live in. `tests/extended/lib_sort.pas` sorts two parallel arrays by the first
one's order, which no interface taking an array could have done.

This is the pattern to reach for wherever an algorithm can be phrased over
positions, and it costs nothing the compiler does not already do (ADR-0030).

## Consequences

**`lib/` joins the differential oracle**, and this is the only harness change.
`selfhost/difftest.sh` now walks `tests/`, `lib/` and `selfhost/`, and
`tests/checks/difftest_check.py`'s `corpus_size()` globs the same three — one
claim written twice on purpose, so changing one without the other fails. Each
module carries a `name.std` sidecar reading `extended`, because `standard_of()`
decides from the path and `lib/` is not `tests/extended/`; without it the
modules would have been compared as ISO 7185, which is two identical rejections
agreeing (ADR-0034's failure).

**The import path is still compared by nothing.** `pascalc-s0` does not
implement `--import` and refuses it, so difftest compares each library module as
a standalone source and each case as a program whose imports do not resolve.
That is the row `doc/sop.md` §7 already carries (ADR-0108), and this increment
makes it matter more rather than less: the library is the first thing here whose
*whole point* is being imported. The three `ctest` cases are what cover the
linked-and-running path, and they are the only thing that does.

**A golden per module is thin evidence and is not the argument.** Each case is
written so that the discriminating lines fail on a plausible wrong
implementation rather than only on a broken one: `IndexOf` over `'abcabc'`
distinguishes first from last occurrence, `Replace('aaa', 'a', 'aa')` fails to
terminate if a replacement is rescanned, the parallel-array sort prints the
permutation that says whether the payload followed its key, and `ISqrt`,
`Lcm(maxint, maxint)` and 200 000 Lehmer draws are all at the top of the integer
range, where the obvious formula traps instead of answering.

**`lib/` is walked by difftest and by nothing else, deliberately.**
`selfhost/irtest.sh` globs `tests/` only, and a module with no `.out` and no
`.err` is skipped there anyway; `tests/checks/coverage.py` enumerates `tests/`,
`tests/extended/components/`, `badparse/` and `badsema/`, so the library's
sources are not among the programs the compiler's own statement coverage is
measured over. Adding them would move a ratchet's recorded per-procedure numbers
and is a catalogue edit to argue for on its own, not a side effect of this one.
The compiler paths the library does exercise are reached through the three cases.

**Nothing here is installed.** There is no `install` target in `CMakeLists.txt`
and this adds none, so a program outside this repository cannot use the library
without naming paths into a checkout. That is the next decision rather than an
oversight, and it is the one the word "standard" in "standard library" is really
about.

**`maxImports = 8`** bounds how many components one program may import, so a
library of more than eight modules cannot be used whole. It reports rather than
truncates (ADR-0110), and it is a constant in `selfhost/compiler.pas` rather than
a design.

### What this does not do

- No foreign-function interface, so nothing here touches the operating system.
  `PasMath`'s generator is arithmetic and reproducible on purpose; there is no
  entropy source to ask.
- No networking, no internationalisation, no concurrency, no memory-safety
  model. `PasStrings` converts ASCII case and passes every other byte through,
  which is the honest behaviour while `char` is a byte and the text model is
  open.
- No containers. A list or a map would be per-element-type, and committing to a
  spelling for that before the dialect exists would be the expensive kind of
  guess.
- No resolution by name, no versioning, no install location.
- No third `--std`, and no change to either conformance mode.
