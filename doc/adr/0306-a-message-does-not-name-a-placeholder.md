# 306. A message does not name a placeholder type

Date: 2026-09-03

## Status

Accepted, 2026-09-03. Closes `doc/roadmap.md`'s row *Four of twelve example
programs collided with a library name on their first draft* (ADR-0295,
finding 3) in both of its parts: the compiler defect it named, and the
library-naming question it raised.

## Context

ADR-0295 wrote twelve example programs and four of them declared a variable
whose name a library already exported. Pascal folds case, so `var info:
InfoResult` beside `import PasFS` is one identifier declared twice. Three of
the four diagnostics were exact. The fourth was not:

```
error: 'info' is already declared in this block
error: 'info' is not a function
error: cannot assign integer to a variable of type inforesult
```

The third line names `integer`, and nothing in the source is an integer.

**The cause is the contract this compiler rests on, read one step too
literally.** `CLAUDE.md` states it: *Sema leaves every node's `ntype`
non-null*, and *on an error path Sema still assigns a placeholder type rather
than nil, so codegen cannot crash on a half-checked tree.* `CheckCall` has
four error arms — an unknown function, a qualified name that is not one, a
procedure in a value position, and a name that resolved to something not
invocable — and each writes `c^.ntype := intType` and carries on. That keeps
CodeGen safe. It also hands the assignment rule a type, and the assignment
rule then does what it is written to do: finds it incompatible and says so,
spelling a type the program never wrote as though the program had written it.

**What hid it for years is that the placeholder is an integer.** Every
existing golden that reaches one of those four arms assigns to an integer
target — `tests/required_shadow_errors.err` is three of them, and
`selfhost/badsema/calls.err`'s `i := nosuchfunction(1)` is a fourth — so the
placeholder matched, `Assignable` said yes, and the second message never
appeared. It takes a target of some other type to see it, and no case had one.

**The precedent for the fix was already in the same procedure.** `badFunc`
guards the *left* side: §6.8.2.2 has already reported this target, so what is
left to say about it is a consequence of that fault rather than a second one
(ADR-0054). The right side had no such guard.

## Decision

**A node whose type is a placeholder says so, and no message names it.**

- `node` gains `nErrType`, a boolean in the fixed part beside `nParen` and
  `nChecked`, cleared by `NewNode` like every other field the parser does not
  fill. It is set at the four `CheckCall` arms above — including the qualified
  branch, which sets it before the lookup and clears it when a result type is
  found, because that branch leaves `intType` behind on a failed lookup too.

- The two assignment type-mismatch messages — `CheckStmt`'s `nkAssign` arm and
  `CheckResultAssign` — do not report when the value carries it. `Assignable`
  is untouched: the refusal is the predicate's and this only chooses the
  words, which is the sentence already written beside that arm. Choosing to
  say nothing is one of the choices.

- **The library naming half is a paragraph and not a rename.** The nouns
  ADR-0295 listed — `Info` in `PasFS`, `Dir` and `List` in `PasDir`, `Parts`
  in `PasText`, `Stream` in `PasStream` — are each the best name for what they
  denote, and the collision is with a name the *caller* chose. `README.md`'s
  library section gains a paragraph naming the five, stating the rule
  (§6.11.2 puts an exported name in the importing block's scope, §6.1 folds
  case) and giving the three answers a caller has: rename the variable,
  `only`, or `qualified`.

## Evidence

`selfhost/badsema/calls.pas` gains three statements, one per reachable arm,
each assigning to `v: vec` rather than to an integer:

```pascal
v := nosuchfunction(2);
v := noargs(2);
v := i(2);
```

Before the change each produced two diagnostics and the second named
`integer`. After it each produces one. The golden holds the three lines.

| Mutation | Killed by |
| --- | --- |
| `not s^.asValue^.nErrType` removed from `nkAssign`'s mismatch arm | `calls`, with three extra lines naming a type nothing declares |

The fourth arm — the qualified `M.f` that is not a function — is covered by
`tests/extended/module_errors`, whose target is an integer; the guard is set
there for the same reason and the golden does not move, which is the arm
argued rather than pinned. Setting it is what stops the same defect arriving
from a module's interface the first time somebody assigns such a call to a
record.

## What is not done

**Only the assignment messages are guarded.** A placeholder can still be
named by an argument mismatch, an operator mismatch or a `for` control
variable's type. Each is the same class and none has been observed; the guard
is a field, so a site that needs it costs one condition. Doing all of them
speculatively would have meant regenerating goldens across the corpus with no
case saying which of the changes was right, which is the shape `doc/sop.md`
warns about — a golden regenerated afterwards proves nothing about the change
that regenerated it.

**Nothing is renamed in the library.** ADR-0298 made every export unique
across modules and is a different question: that one is the library against
itself, and this one is the library against a program not yet written. Every
answer that renames an export moves the collision rather than removing it —
a caller who wanted `info` for a variable wanted it because it is the right
word, and so did `PasFS`. ADR-0116's bar asks for a client that cannot get its
work done, and there is none: the collision is a compile-time error the caller
reads in the same second and answers in one word.

**`import` gains nothing.** A per-import rename — `import PasFS (Info as
FsInfo)` — is what a language with this problem eventually grows, and §6.11.2
already has `only` and `qualified`, which cover it at the cost of a qualifier.
No program here has wanted the third spelling.

## Consequences

**A placeholder is a decision and not an absence.** The contract says every
node has a type on every path; what this record adds is that a type invented
by an error path is not a fact about the program, and the difference has to be
recorded where it is invented rather than guessed at where it is read. There
is one placeholder here — `intType` — and its being a *real* type is what made
the defect invisible for as long as every target happened to be one.

**The corpus could not see it because the corpus is exact.** Every one of the
four arms had a golden, and `diagnostic-coverage` reported all four covered.
Coverage of a *message* is not coverage of the message's *interaction* with
the rule that runs next, and this is the second time a follow-on diagnostic
has been the defect (ADR-0054 was the first, on the other side of the same
statement).
