# ADR-0415: A method may name itself through a receiver

## Status

Accepted.

## Context

ADR-0410 gave a method-designator three shapes and ADR-0412 recorded what that
costs: *every one of them has to be taught the same fact*, because they are
three different places in the compiler. This is the fifth time that has been
the finding, and it was found by writing a linked list.

Inside an implementation, a method may be reached through a receiver. Whether
it may name the routine whose declaration contains it depended on which of the
three spellings was used:

| spelling | itself | an earlier method | a later method |
| --- | --- | --- | --- |
| statement, parameterless — `l^.next.Bump` | worked | worked | refused |
| expression, with arguments — `l^.next.Deep(n)` | worked | worked | refused |
| expression, parameterless — `l^.next.Len` | **refused** | worked | refused |

The ordering column is §6.2.2.9 and was right everywhere. The first column was
not, and the refusal read *cannot select a field of a value of type link, and
no routine of that name is implemented for it* — which is what a reader gets
for a name nobody implemented, on a name the same file implements twenty lines
above.

**The two that worked did so by accident.** `CheckCall` and `CheckStmt` both
look the identifier up in the scope first and prefer `MethodSym`'s answer only
when there is one; §6.2.2.9 puts a routine's own identifier in scope in its
body, so the recursion resolved through the *scope* while `MethodSym` answered
nil. The husk has no such fallback — it asks `MethodSym` and nothing else —
so it was the one spelling that reported what was actually the case.

What was actually the case is that a routine joined its implementation's list
**after** its body had been checked:

```pascal
if r^.pdBody <> nil then CheckProcBody(r);
if r^.pdSym <> nil then
  AppendSym(im^.routines, im^.routineTail, r^.pdSym);
```

## Decision

**A routine is appended to its implementation before its body is checked.**
The two lines are swapped, and `MethodSym` then answers for the routine being
declared in all three spellings.

Written order goes on deciding, and that is why the loop is the right place
rather than a pass that registers every routine up front: the loop appends one
routine at a time, so while an earlier body is being checked a *later* routine
is still not in the list. AP 6.7.10.4 gains NOTE 17a saying so, because a
method-designator reaches a routine by the receiver's **type** rather than by
the scope, which could otherwise be read as making a whole implementation
available at once.

This also removes the accident. The scope fallback in `CheckCall` and
`CheckStmt` is still there and still right — ADR-0412 has `MethodSym` win
where it answers — but it is no longer what makes recursion work, so the three
spellings now agree because they are told the same thing rather than because
two of them had a second way to find out.

## Consequences

- `tests/dialect/methods.pas` gains `SelfByReceiver`: a chain of three cells
  with `Count` (the husk naming itself), `Total` (with arguments, naming
  itself), `Nudge` (a statement, naming itself) and `Doubled` (naming an
  earlier method), printing `3 9 6`. The golden gained that line and nothing
  else.
- `tests/dialect/methods_errors.pas` gains the other direction: a method naming
  a *later* one, in both spellings, because they are refused by two different
  paths and carry two different messages — *cannot select a field of a value of
  type rung* for the husk and *unknown function 'latetoo'* for the with-arguments
  form.
- The mutation is the swap put back: `methods` fails at the husk with the
  original diagnostic and `methods_errors` still passes, so the two halves are
  independent.
- `lib/dialect/paslist.pas` was written around the defect, using the bare
  spelling `Len(l^.next)` — which is correct, idiomatic and unaffected. It is
  left as it is: the fix admits a second spelling rather than obliging one.
- `doc/sop.md` §7's row for this is struck, one commit after it was written.

## Alternatives rejected

**Give the husk the same scope fallback the other two have.** It would make
the three agree by giving all of them the accident instead of none, and the
fallback answers for a name in scope that may be a routine of some *other*
type — which is exactly what ADR-0412 took away from the qualified form.

**Register every routine of the implementation before checking any body.** It
would admit a method naming one declared after it, which §6.2.2.9 refuses for
every other kind of routine and which nobody asked for. `forward` is how
Pascal spells that when it is wanted, and an implementation-routine can carry
one.

**Leave it and document the bare spelling.** It was the position for one
commit, and `doc/sop.md` §7 carried the row. The argument against is that the
refusal names nothing a reader can act on: a method that is implemented,
reported as not implemented, in the file that implements it.
