# 295. A corpus written to be read

Date: 2026-09-03

## Status

Accepted, 2026-09-03. Closes the row *No program to read that is not a test*
in `doc/roadmap.md`'s chapter *What would make this practical to pick up*,
and opens the findings below where that chapter said the next one would
come from: somebody writing a program.

**Finding 6 is wrong about where the bound is**, and
[ADR-0310](0310-the-key-capacity-is-the-programs.md) corrects it: the map has
been generic over its key type since ADR-0254 and 63 is `MapKey`'s capacity,
not the map's.

## Context

Every Pascal source in this tree was one of four things: a test case, a
library module, the compiler, or the language server. The programs that were
not tests were 50 690 lines between them, and a test case is written to pin
a clause, which is the opposite of what a reader wants — it prints
`ok=TRUE cause=2` where a program would print an answer. There was nothing a
person who knows Turbo Pascal could read over coffee to learn what an owned
pointer is *for*, or what `T ! E` looks like at the point of use.

`doc/roadmap.md` had said, when its *What a daily program still cannot reach
for* chapter emptied, that the next entry would come from somebody writing a
program and finding it hard. Nobody had written one. The last three defects
closed here (ADR-0290 to ADR-0292) were each found by a probe of a few lines,
which is the same observation from the other side.

## Decision

**`examples/` is a fourth corpus**, and it is held to the same harness as
the other three: twelve programs of a page each, every one with a `.out`,
registered by a fourth `file(GLOB)` in `CMakeLists.txt` as
`example-<name>` with `tests/dialect/`'s `TIMEOUT`, because one of them opens
a socket. `tests/run_test.sh` needed nothing: an example is a case, and the
sidecars it reads are the ones a case already has.

Three things were decided about the shape.

**An example resolves the library by name.** The seven that import a module
carry an `.importpath` sidecar naming `../lib` and `../lib/dialect`, and no
`.components`. That is the `--import-path` line `README.md` teaches, written
down beside the program, and it makes the examples the first cases here that
drive ADR-0244's resolver over the whole dialect library from outside
`tests/`.

**Every example must be quiet and deterministic**, which the harness already
enforces: a case without a `.warn` sidecar may produce no warning
(ADR-0272), and a golden is compared byte for byte. Two examples take their
input from a `.in`; two make a directory beside their first argument and
remove it; the HTTP one listens on service `'0'` and connects to itself, for
`tests/dialect/lib_http.pas`'s reason — a case that reached a web site would
be a test of the site. `hello_args.pas` prints the last component of each
argument and never the directory, because the harness passes two scratch
paths that differ on every run.

**The sweeps that enumerate Pascal by root name it.** `format_check.py`,
`variant_check.sh`, `coverage.py`, `heap_balance.py`, `fuzz.py`,
`sanitize.sh` and `irtest.sh` each gained `examples/`, so the programs are
formatted, variant-checked, covered, leak-counted, mutated, sanitised and
run through the stage-2 compiler like the rest. `warning_free.py` does not
name it: that gate is for sources with no sidecar, and an example is held to
the same claim by `run_test.sh`'s `.warn` rule in both directions.
`fpc_differential.py` cannot: every example but three uses the dialect, and
FPC refuses those.

**And `heap_balance.py` grew twice on the day**, both times because of what
the examples are. Its filter grepped a source and its `.components` for
`new(`, which sees nothing of a module reached by `.importpath`, so
`json_pretty.pas` — which allocates a tree through `PasJson` — was not a
heap-using case to it. A case with that sidecar is now measured, on the
gate's own argument that a case which turns out not to allocate is a balance
of zero and not a failure; `tests/extended/import_by_name.pas` joined the
catalogue with the examples for the same reason. And `--write` had dropped a
case that did not run **in silence**: the first regeneration, run from a
shell without the environment ctest hands the language server's harness,
wrote a catalogue with `pasls` struck from it and printed `44 cases
recorded`. It now prints every case that did not run and writes nothing.

## What writing them found

This list is the deliverable as much as the programs are. Nothing below is
fixed here except the two harness changes above; each row says where it
would go.

1. **`release(c)` on a channel a task was handed does not close it, and a
   program that expects it to deadlocks with no diagnostic.** The first
   draft of `pipeline_tasks.pas` was a producer, a filter and a reader, each
   stage closing the channel downstream of it as `concurrency.pas`'s main
   program closes its job channel. It compiled and hung at once. The runtime
   says why, in a comment on `pas_chan_unref`: a task's parameter is
   initialised with a closer that *drops the reference and does not close*,
   because a worker that has finished must not close a channel its
   colleagues are still draining. That is a sound rule for a pool and it
   makes a pipeline unwritable by close; the example ends its stages on a
   sentinel instead and says so in its header. Neither `README.md` nor
   AP 6.9.3.13 states it, and the compiler admits the call. The cheapest
   answer is to refuse `release` of a channel parameter inside a task at
   compile time, since it can never do what the program means; the second
   is to say in the spec that a task may not close what it was lent.
   *For the roadmap's concurrency row.*

2. **A map lookup is the most verbose call in the program that uses it.**
   `MapGet(CountMap, integer, counts, w, 0, StrHash, StrEq)` — seven
   arguments, two of them types the call already knows, because a type
   parameter appearing only in the result must be written and ADR-0254's
   rule is all or nothing: once one type is written, every type is.
   `MapPut(counts, w, n + 1, StrHash, StrEq)` beside it writes none.
   `word_freq.pas` reads as a program about `MapGet`'s signature. A `MapGetOr`
   taking a `var` destination, or inference that takes `Ptr` from `counts`
   and still asks for `Elem`, would each halve it. *For the roadmap's
   library row on inference.*

3. **A library name that is a noun is a name a caller wants for a variable,
   and four of twelve programs collided with one.** `Line` and `line`,
   `Parts` and `parts`, `Info` and `info`, and a task `Squares` beside a
   channel `squares` — Pascal folds case, so each is one identifier declared
   twice. Three of the four diagnostics were exact (*'parts' is already used
   in this block, so declaring it here would give one name two meanings*);
   the fourth was not: `info := Info(child)` with `info: InfoResult` reports
   *'info' is not a function* and then *cannot assign integer to a variable
   of type inforesult*, the second line naming a type nothing in the source
   holds. `tests/dialect/lib_dir.pas` already carries a comment warning about
   `Dir` for the same reason. The cost is `PasFS.Info`, `PasDir.Dir`,
   `PasDir.List`, `PasText.Parts`, `PasStream.Stream`: every one is the word
   a caller reaches for first. *For the library; and the second diagnostic
   for the compiler.*

4. **An owned pointer cannot be assigned `nil`, and the refusal does not say
   what to write instead.** A handle takes `h := nil` as its early release
   (ADR-0202); an owned pointer answers *an owned pointer may be assigned
   only 'take' of a variable of its own type: it owns what it identifies,
   and there is no copy*. True, and the reader wanted `dispose(p)`, which the
   message does not name. Whether `p := nil` should simply be admitted as
   the same operation is a spec question — AP 6.4.14 gives the two owned
   kinds different releases for no reason a reader can see. *For the spec,
   or failing that the message.*

5. **`PasJson` renders `0.75` as `7.500000000000E-01`.** Valid JSON, and the
   form no pretty-printer wants: it is §6.9.3.4.1's default real output
   passed through unchanged. `json_pretty.pas` prints it as it is, and its
   golden holds the number in that spelling so that the day it changes is
   visible. *For the library.*

6. **A `MapKey` is 63 characters and a longer key stops the program.**
   `word_freq.pas` has to guard `if length(word) <= KeyMax` before every
   `MapPut`, because assignment to a `string(63)` traps on 64 — which is
   right for the language and means a map keyed by *text from outside* needs
   a line the example has to explain. A `Map` keyed by `string(4096)` costs
   4 KB a slot. *A bound, recorded, not a defect.*

7. **A program that wants somewhere writable must ask `argcount` first.**
   `argument(1)` outside `1..argcount` stops the program (AP 6.7.6.10), so
   `defer_cleanup.pas` and `dir_sizes.pas` each begin with an `if argcount
   >= 1`. Correct, and the shape every such program will carry.

What was looked for and **not** found: no compiler defect, no crash, no
wrong answer, no bound in the compiler hit, and no library routine that
answered wrongly. Every one of the twelve compiled with no warning on its
first warning-free draft — the four warnings fired on nothing a reader would
have kept.

## Consequences

- Twelve more cases, 0.8 s under `ctest -j3`, each read by `irtest.sh`'s
  stage-2 compiler and by six sweeps besides.
- `tests/checks/heap_balance.txt` gains nine rows, all zero, and one of them
  (`import_by_name`) is not an example.
- A source added to `examples/` without a `.out` is a failed case, not a
  skipped one: the glob registers it and `run_test.sh` reports *missing
  expected-output file*. `irtest.sh` skips such a source, as it skips a
  component under `tests/`, and is not the gate for this.
- The seven findings above go to `doc/roadmap.md`'s *Writing a daily
  program*; the row that asked for the examples goes to `doc/history.md`.
- Two gates were found reading nothing when the checkout is itself a
  `.claude/worktrees` tree — `diagnostic-coverage` reported 663 unnamed and
  `foreign-layout` *no claim anywhere* — because each skipped any path with
  `.claude` in it and tested the absolute path rather than the path below
  the root. Both now test the relative path, so the suite means the same
  thing in an agent's worktree as in the checkout that holds it.

## Alternatives rejected

**Examples under `tests/dialect/`.** They would be registered without a
change to `CMakeLists.txt` and would drown: a reader looking for a program
to copy would meet `trap_text_illformed.pas` first. A directory named for
its reader is the whole feature.

**Examples that are not cases.** The row that asked for them said *it is the
one row here that pays twice*, and an example nothing runs is the README's
code blocks moved to another file — which is how three of those blocks came
to describe a compiler that no longer existed.

**Fixing the findings in the same change.** Each of the seven is a decision
of its own, and two of them (1 and 4) are spec questions. Recording them
where they can be taken separately is what the roadmap's *a row should be a
report, not an estimate* asks for.
