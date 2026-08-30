# 272. A diagnostic that is not an error

Date: 2026-08-31

## Status

Accepted, 2026-08-31.

## Context

Every diagnostic this compiler could write was an error. 523 `ErrorAt` sites in
ApFront, four in ApTypes, two in the program, and no second severity anywhere —
so `lib/dialect/paslspdiag.pas` wrote LSP's severity as the constant 1 and its
own comment said why: *no warning and no note, so a second severity would be a
branch no input reaches.*

What that costs is a whole category of thing the compiler cannot say: **this
compiles and is probably wrong.** An unused variable, an unused import, a `var`
parameter never written through, a function whose result is assigned on one
path and not another, a statement after an unconditional `goto`. `doc/roadmap.md`
lists them and none was sayable.

The insertion point was already clean — Sema accumulates rather than stopping —
and the shape of the answer was already decided by `ErrorAt`, which is the one
place the diagnostic format lives.

## Decision

`WarnAt(l, c)` beside `ErrorAt(l, c)`, in ApTypes, and **the only difference is
`errorSeen`**. Same format, so every reader that parses `file:line:col:` already
handles it. Same stream, because neither standard gives a program a second one.
Same exit status, because a warning that failed a build would be an error with a
softer word for it. No `errorCount` either: that one names a schema's domain
(§6.4.7) and a remark must not move it.

The first warning is **a local variable declared and never used**, and it needed
one field: `used: boolean` on the symbol, set in `NoteUse` — which is where
Sema records a resolution and is called at every applied occurrence there is. It
is set whether or not anything is being dumped, `NoteUse` having been written
for `--dump-uses` and guarded by it (ADR-0246). Recording it there rather than
walking the finished tree is ADR-0111's rule and ADR-0230's met a third time: a
hand-written walker can miss a node kind in silence and no gate here would see
it.

**Four exclusions, each a false positive rather than a message left out.**

- A **parameter**. What formals a routine has is decided by its callers and by
  §6.11.1's heading, not by its body.
- A variable at **level 0**, which is the program's or a module's (ADR-0016
  gives a level-0 owner one activation and a global). A module's may be
  exported and used only by an importer; a program's may be a program-parameter
  that §6.5.1 binds externally and §6.12 activates without the program ever
  naming it. This compiler's own twelve program-parameters are exactly that.
- A **bindable** variable, for the second half of the same reason: §6.7.5.2
  makes it an interface to something outside the program.
- Anything in another **file**. An `--import` names a source and §6.11.1 puts
  the interface in its module-heading, but Sema reads and checks the whole
  component — so without `curFile = mainFile` the compiler's own program
  reported eleven warnings about ApFront, once per importer, about a file the
  command line never asked to be compiled.

**And nothing at all once anything has been reported.** The evidence stops
being evidence the moment resolution fails: a name that did not resolve records
no use, so a variable named only in a statement Sema refused reads as one
nothing named. `tests/dialect/slice_escape.pas` is that exactly — five
variables whose only occurrences are the escapes the case exists to refuse, and
every one was called unused underneath the five errors that are the point of
the file. That was three failing goldens before the guard and none after.

**A dump writes no warning.** Every `--dump` flag is named in `warnOn`, not
`dumping` alone: that variable answers *which format a diagnostic takes* and
covers four of the twelve, where the question here is whether anything at all
may be added to what a reader is parsing. `kind-exhaustive` reads
`--dump-dispatch` and stopped on the first warning ever written, with *"wrote a
line this does not understand"*.

## Consequences

**It found twelve dead declarations in this compiler on its first run** — eleven
in ApFront and one in the program — including six in a single `var` line of
`DeclareProcHeading`. They are removed here. Across the rest of the corpus it
is 24 warnings in 11 files of 765.

**`name.warn` is a new sidecar and it had to be.** Neither of the two that exist
can hold a warning: `.out` compares what the *program* printed and `.err`
requires a non-zero exit, so a remark made by a *successful* compilation was
pinnable by nothing at all. The rule is two-directional and the second half is
the load-bearing one: **a case without the sidecar must produce no warning.**
Otherwise a warning added later would appear on dozens of cases and every one
would stay green, which is the shape ADR-0067 keeps finding. Both directions
are checked by mutation — a golden line changed fails, and a dead local added
to `tests/hello.pas` fails with *"the compiler warned and no hello.warn says
so"*.

`diagnostic-coverage` reads `*.warn` alongside `*.err` and `*.dump`, so a
warning is held to the same rule as an error: a message no golden names is a
message nothing checks.

**What `used` does not mean.** `NoteUse` does not know whether an occurrence
was a designator being assigned to or an expression being evaluated, so a
variable only ever *written* counts as used. That is narrower than a dead-store
warning would need, and `tests/unused_local.pas` pins it so a later one is
written as a new thing rather than as a change of mind here.

**What is not decided.** There is no flag to turn warnings off. One would be
surface with no caller (ADR-0116), and the corpus says the volume does not
demand it yet; the first caller that wants quiet gets to shape it.

**And a hole this uncovered, in the gate that was supposed to be watching.**
The new message begins with a doubled quote — `writeln(''' is declared here and
never used')`, the offending name written first — and `diagnostic-coverage`
matched messages with a regex requiring an ordinary character after the opening
quote. So it could not see the new message, and could not see **121 others in
ApFront alone**, a quarter of them. It reported the set as fully covered by
never asking about one. That is its own record.
