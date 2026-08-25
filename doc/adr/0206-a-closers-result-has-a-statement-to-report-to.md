# 206. A closer's result has a statement to report to

Date: 2026-08-25

## Status

Accepted. AP 6.4.12.5, `release`, and the second of the two things
`doc/roadmap.md` said the handle left open behind it.

## Context

`runtime/pasrt.c` has carried the argument for this clause since ADR-0174,
written as the reason for the gap rather than as a request to close it:

> Release what the slot holds, if anything. The closer's result is
> deliberately not inspected: a handle is released on the way out of a block
> and **there is no statement left to report to**.

That is true of every release AP 6.4.12.3 lists — a block terminating, a
`goto` past it, a `halt`, a `dispose`, the assignment of an external's answer,
the assignment of `nil`. None of them is a place a program could receive an
integer. So a handle could own a foreign resource and never say whether
letting go of it worked.

**What a closer answers is not a formality.** `pclose` answers the child's
wait status. `fclose` reports a flush that failed, which is the last chance to
learn that a file was not written. `PasProcess.Capture` is the client that had
to live without it, and what it did instead is the whole argument:

- the command was wrapped in a subshell, `( cmd ); printf '\n\001%d' "$?"`;
- the reader split the stream at a marker — a newline and the character 1 —
  taking the digits after it as the exit code;
- so a program that wrote a control character 1 at the start of a line was
  **misread**: everything after it became the status and everything before it
  became the whole output.

The module's own header said so, and the roadmap carried the row: *the
language change would be a handle whose closer's result is kept somewhere a
program can read it, and nothing has said where.*

## Decision

**`release(h)` is a required function of the dialect.** It releases what the
handle variable holds, yields what the closer answered, and leaves the
variable empty. The result type is `integer`.

**It is `take`'s shape with the position rule removed, and the difference is
the reason there is none.** AP 6.4.14.6 confines `take` to the right side of
an assignment to a variable of its own type, because what it yields is an
*owned value* and anywhere else it would be held by no one. What this yields
is an integer. Nothing is left unowned by writing it in a condition, so a
function-designator may stand wherever an integer may be written — and
`if release(a) = 0 then` is a scenario of the clause.

**An empty variable answers zero and is not an error.** That is the assignment
of `nil` (AP 6.4.12.2, ADR-0202) rather than `dispose` of nil: a program that
released nothing has nothing to be told about. A caller needing to tell
"closed, and the closer said zero" from "there was nothing to close" has the
variable itself to ask, before.

**The spelling is ADR-0140's second shape**, a required identifier shadowable
by §6.1.3 — `exit`'s answer, `try`'s and `take`'s. No word-symbol is reserved,
and `release_refused.pas` and `release_refused_iso.pas` are the Annex B row:
under both conformance modes the name resolves to nothing.

**The emptying stays in the runtime.** `pas_handle_release_result` is
`pas_handle_release` with the result kept — the same three lines, not a second
copy of them beside the first, because a copy is free to drift and this is the
invariant 6.4.12.3's "at most once" rests on.

## Consequences

**`PasProcess` loses the marker, the subshell and the wrapping**, and the
reader loses its lookahead: it used to have to know the character after every
newline before it could hand that newline over. The existing golden passes
**unchanged** with all of it removed, which is the strongest thing that can be
said for a simplification. `tests/dialect/lib_process.pas` gains the case the
marker could not survive — `printf 'x\n\001 7\nz\n'` — which now comes back as
eight characters of text and a code of 0.

**A duplicate diagnostic was found and fixed, and it was `take`'s too.**
`CheckCall` checks every builtin's arguments before dispatching, and
`CheckTake` checked its argument again — so an argument that was itself
refused reported the same mistake twice. `CheckRelease` was written from
`CheckTake` and inherited it within the hour. Both now leave the check to
`CheckCall`, and the `ExtStream`/`ExtFopen` line of each error case is what
pins it: an external's function-designator is the only handle-typed or
owned-typed expression that is not a designator, so it is also the only way to
reach either routine's *designator* arm. `take`'s had never been reached.

**`kind-exhaustive` named every place a new `builtinKind` constant had to go**,
including one nobody would have looked at: the constant folder's list of
builtins that fold to nothing. A `release` in a constant-expression cannot
reach it — the argument is a variable, so `EvalConst` fails first — but an
unnamed constant in an exhaustive `case` is a compiler that stops, and the
gate does not accept "unreachable" without an entry.

**AP gains 6.4.12.5 and four scenarios**; the traceability gate refused to let
the clause exist without a triage row, which is ADR-0106 working.

**What this does not do**: it says nothing about a closer's result at any
*other* release. A block ending still discards it, and must — there is still
no statement there. A program that needs the answer must ask for it.

## What was measured

| mutation | outcome |
| --- | --- |
| the closer's result is discarded (`h->closer(h->value)` without the assignment) | `handle_release` fails |
| the slot is not emptied afterwards | `handle_release` fails — the block closes it a second time |
| `Capture` answers 0 instead of `ExitCode(status)` | `lib_process` fails |

The first is the one that argued for the shape of the test. With `fclose` as
the only closer every release answers 0, and a processor that threw the result
away would print exactly the right goldens — so `handle_release.pas` runs a
child through `popen` that exits 7 and reads its status back. A feature whose
correct answer is always zero is a feature no test can hold.

All three are files in `tests/mutation/mutants/`, which is ADR-0207.

## Alternatives rejected

**A second declaration form** — `handle external 'pclose' reporting` — which
would keep the result for every release of that type and put it somewhere.
There is nowhere: the releases 6.4.12.3 lists are not statements.

**Binding the closer directly and calling it as an ordinary external.** AP
6.4.12.4's lend already admits `function pclose(p: Pipe): integer; external`,
and it is what `PasProcess` could not do: the variable goes on owning an
address that has been released, and the block closes it again. That double
close is the defect this clause exists to make unnecessary.

**Answering a fallible-type**, `integer ! ErrorCode`. The closer answers an
`int` and what it means is the closer's business — 0 and EOF for `fclose`, a
wait status for `pclose`. Deciding here which values are failures would put
one C convention in the language.

**Making it an error to release an empty variable**, as `dispose` of nil is.
The nearer analogy is the assignment of `nil`, which AP 6.4.12.2 makes
harmless on an empty one, and a library closing a resource twice on a path it
does not control is the ordinary case rather than a defect.
