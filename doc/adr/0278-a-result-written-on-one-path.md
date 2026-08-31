# 278. A result written on one path

Date: 2026-08-31

## Status

Accepted, 2026-08-31.

## Context

ISO/IEC 10206:1991 §6.7.2 requires a function-block to write its result at
least once, and this compiler reports a body that never does. What nothing
asked is whether the one assignment stands where **every** path reaches it: an
`if` with no else-part, or one arm of two, leaves the result whatever the frame
slot happened to hold, and the program compiles, runs and prints it.

That is ADR-0272's category exactly — *this compiles and is probably wrong* —
and it is the third of the four warnings that record listed. ADR-0277 took the
first of the remaining three and closed by naming this one.

The **fourth** was measured in the same sitting and is not built. A `var`
parameter never written through would be spelled `protected var` (§6.7.3.1),
and the numbers are worth keeping: 111 sites in 53 files, of which
`Protectable` — §6.4.1's own predicate, which the compiler already owns —
removes 30, because a file or a pointer cannot be protected at all and the
warning would otherwise have advised something the compiler refuses. Of the 81
left, 32 are in the compiler, the language server and the library, and every
one of them is right.

It is not built because **the fix is not always legal and no component can
tell**. §6.6.3.6's congruity compares the formal-parameter-lists, `protected`
included, so a procedure passed as a procedural parameter cannot take the word
— `selfhost/badsema/procparams.pas`'s `ByRef` is that case in this tree — and
whether a routine is ever passed that way is a whole-program question an
exported one cannot answer at all. The sound version warns only for a routine
that is neither exported nor passed as a procedural actual anywhere in the
component, which needs the warnings deferred to the end of a compilation rather
than written where they are found. That is a change to ADR-0272's discipline
and wants a record of its own.

## Decision

`WritesResult(s, res)` walks the statements and answers whether every path
through `s` writes the result. Three shapes answer yes and each must:

- a **statement-sequence**, as soon as one of its statements does;
- an **if-statement**, only with both arms — so no else-part is an outright no,
  and one arm of two is not enough either;
- a **case-statement**, with every arm *and* the completer — unless there is no
  completer at all, §6.9.3.5 stopping the program when no label matches, so a
  path that returns is a path that took an arm.

§6.7.5.7's `halt` answers yes for that second reason and writes nothing: no
path through it returns to read a result. AP 6.7.5.9's `exit(e)` writes and
leaves, and the walk finds the assignment Sema moved into the husk (ADR-0044),
so it needs to know nothing about the procedure.

A **while** and a **for** answer no, either may run its body no times. A
**repeat** answers no as well — AP 6.7.5.10's `break` leaves it from anywhere
inside — *except* when its condition is the constant `false`, which is never
left by falling out of it at all; `repeat … until false` is how
`lib/dialect/pastls.pas`'s `ReadLine` is written, and without that arm the
analysis reported its own blind spot as a defect.

Everything else answers no, which is the conservative direction: the `case` has
an `otherwise` and a statement kind added later falls to it as *does not
write*, so a new construct costs a missed warning and never a false one.

Four things silence it, and each is a case the walk cannot decide rather than
one it decides in the program's favour:

- a **`goto`** anywhere in the body, which turns the statement tree into a
  graph — a jump past an assignment or back over one is a path the walk does
  not see, in either direction;
- **no assignment found in the body at all**, which means §6.8.2.2's nested one:
  "the function-block … shall contain the assignment-statement" is containment
  and not identity, so a procedure declared inside the function may write its
  result;
- a **result-variable-specification**, `function f: T = r`, which is the one
  spelling that gives the result a name a statement can write down — and so the
  one where §6.9.4's other threats apply, a `read` into the result and a var
  argument among them. Without a name there is no way to write the result but
  an assignment-statement and `exit(e)`, which is exactly what the walk models;
- a result-type already reported wrong.

ADR-0272's three guards are unchanged: `warnOn`, `not errorSeen`,
`curFile = mainFile`.

## Consequences

**It found one thing in the corpus and it was in this compiler.** Over the 779
tracked sources the sweep reported `ResolveRestricted`, where a `done: boolean`
stood between two if-statements: the first answered the error cases and set the
flag, the second ran `if not done`. Every path did write the result and the
analysis could not see it, because the correlation between the flag and the
assignments is not in the tree. The flag is gone and the second if-statement is
the first one's `else` — one fewer variable, one correlation fewer for a reader
to hold, and both coverage ratchets moved the right way for it.

Two more were found and then answered by the analysis rather than by an
exception: `lib/dialect/pastls.pas`'s `ReadLine`, which is the
`repeat … until false` arm above, and `tests/dialect/try.pas`'s `armed`, whose
`for k := 1 to 2` has constant bounds a smarter walk would fold. The second is
**not** modelled and takes a `.warn` sidecar instead, because folding the
bounds is only sound with a scan for `break` and `continue` in the body, and
one sidecar is a cheaper true statement than a second analysis.

`tests/dialect/partial_result.pas` is the case: nine functions that are
reported and eleven that are not, with a `.components` sidecar naming a module
whose own function has the defect, so the importer proves `curFile = mainFile`
by saying nothing about it. Fourteen mutations were made and every one is
killed by a named case — the `and` between an if's two arms, the case arms, the
completer, the repeat's condition, `halt`, `exit`, `goto`, the nested
assignment, the result-variable form, the sequence's any-versus-all, `with`,
`labelled`, and each of the two guards a `--dump` and an `--import` protect.

Every decision the new code writes is **taken in both directions by the
corpus**, and getting there deleted four nil tests no compiling program can
reach. `branch_coverage.txt` went from 853 never-taken directions to **852**
over 58 more, and `line_coverage.txt` from 393 unreached statements to 392 over
64 more — the improvement in both being `ResolveRestricted`'s dead arm.

`tests/dumps/warnings.pas` gained a third defect, so the `warnOn` guard is
pinned for all three warnings by one golden.

One of ADR-0272's four remains, and it is the one that record already doubted:
an unused import, which §6.2.3.6 makes meaningful on its own — a module is
commenced before the program-block, so importing purely for a `to begin do`
part is a thing someone does on purpose.
