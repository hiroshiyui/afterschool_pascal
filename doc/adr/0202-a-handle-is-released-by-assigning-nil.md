# 202. A handle is released by assigning nil

Date: 2026-08-25

## Status

Accepted. AP 6.4.12.2's second form of assignment.

## Context

ADR-0174 gave the dialect a handle-type and one form of assignment: the
answer of an external function of the same type. That is what makes 6.4.12.3's
"a variable shall release a value at most once" keepable — a value is born in
one place and the variable that receives it owns it.

It also means a program cannot release a handle before its own variable dies.
Both modules built over the type wanted to. `PasStream.Close` and
`PasDir.Close` each assign the answer of a call they know will fail —
`fopen('', 'r')` and `opendir('')` — because the release is the *assignment's*
and a null answer leaves the variable empty. It works, and it costs a refused
system call, a stale `errno`, and a `PasOS.LastErrorText` after `Close` naming
the empty path rather than whatever had actually failed.

`doc/roadmap.md` recorded the spelling that would remove it and said it "waits
for a second module to want it". `PasDir` is the second module, and it wanted
it on the day it was written.

## Decision

**`h := nil` releases what the variable holds and leaves it empty.**

**It assigns no value**, and that is why it fits rather than widening the type.
`nil` denotes the empty state of every handle-type — 6.4.12.2's own second
paragraph, which already admits it on the right of `=` — so the type still has
exactly one way to *acquire* a value and this is a way to give one up. Every
restriction ADR-0174 argued for is untouched: no copy, no second name, no
value parameter of a routine that is not an external-declaration, no result.

**No spelling question arises.** ADR-0140's test is whether a conforming
program could have written the construct in that position, and a handle-type
exists only in the dialect: a conformance mode refuses `handle external` at the
denoter, so there is no program under either standard in which `h := nil`
means anything at all.

**One Sema arm and nothing else.** `pas_handle_set` already releases what the
slot holds before storing, and `EmitExpr` of `nil` is a null pointer — so the
existing lowering of the first form *is* the second form when the value is
null. CodeGen was not touched and neither was the runtime.

## Consequences

**Two library routines get shorter and stop lying about `errno`.**
`PasStream.Close` and `PasDir.Close` are `s := nil` and `d := nil`.

**`tests/dialect/handle_nil.pas` is the case, and its evidence is a loop.**
Two thousand streams opened and closed through one variable: `run_test.sh`
runs every case under `ulimit -n 256`, so a release that does not happen stops
the program at about the two hundred and fiftieth. That is
`str_arena_loop.pas`'s argument and it needs the same thing to be true — a
bound low enough that exhausting it is cheap. Removing the release from
`pas_handle_set` fails the case; removing the Sema arm refuses the program.

**Releasing an empty handle is not an error**, and the case says so on its own
line. The runtime releases what the variable holds and it holds nothing, so a
library's `Close` may be called twice, which is what a caller of a `Close` that
answers nothing will do.

**Two scenarios**, and the second is the one that keeps the decision narrow: a
`^integer` holding `nil` is still refused, because what is admitted is the
*token* in that position and not a null pointer value.

## What this does not do

**It does not give the type a second way to acquire a value.** 6.4.12.4's
crossing is unchanged and so is 6.4.12.2's first form; a handle still comes
from an external function and from nowhere else.

**It does not make the closer's result reachable.** 6.4.12.1 discards it, which
is what `PasProcess` works around for `pclose`'s wait status, and this
assignment discards it exactly as a block exit does. That is
`doc/roadmap.md`'s other handle bullet and it is untouched.

**It does not release anything a block would not have.** The variable's own
lifetime still ends with a release; this only moves the moment earlier.

## Alternatives rejected

**A required procedure — `close(h)`.** It would be a required identifier,
which §6.1.3 lets any program shadow, and it would take a spelling from every
program that does not. `nil` costs no name and is already the word for the
state the variable ends in.

**Leaving it alone, since `fopen('', 'r')` works.** It works and it is a lie
told to the operating system to get a side effect, which is the shape a reader
has to be told about — both modules' headers carried a paragraph explaining it.
Two paragraphs of apology is what a missing language form looks like.

**Admitting any null pointer**, so that `h := q` with `q = nil` releases. It
would make the type's admissible right-hand sides depend on a *value* rather
than on the construct written, so whether a program is legal could not be
decided at translation time. The refusal of `a := q` is a scenario for that
reason.
