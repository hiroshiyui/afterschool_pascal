# 289. The last legal span, rather than the first illegal one

Date: 2026-09-02

## Status

Accepted, 2026-09-02. Fixes what ADR-0288 recorded and declined to fix.

## Context

An array's index-type has been bounded since the conformance sweeps: a
subscript is lowered to `i - lo` in the integer type, without a check, so the
bound has to guarantee that `hi - lo` *is* a value of that type. The integer
type here is `-maxint..maxint` (ADR-0014), so the condition the lowering needs
is `hi - lo <= maxint`.

Sema refused at `hi - lo >= maxint`, one step early. ADR-0288's audit found it
by the shape of the two refusals rather than by reading the arithmetic: this
compiler refused a 2 147 483 648-byte array for its element count while
accepting a 2 400 000 000-byte record, so the refusal was not a capacity limit
and ISO 7185 §1.2 a) — the only clause that would permit it — does not reach
it. What it cost is `array [0..maxint] of T`, which is how a Pascal program
spells an index as wide as one goes.

**`verify/iso.py` said `< maxint` too**, while its own docstring gave the `<=`
reason. The model and the compiler agreed, so `verify/` proved the lowering
sound under a precondition one narrower than its stated justification, and
every rule passed.

## Decision

Make the comparison strict: `hi - lo > maxint` is refused, `= maxint` is
accepted.

**`TypeLength` is widened to `int64`** (ApTypes). A span of maxint is a count
of maxint + 1, which is not an `integer`, so the old body trapped in the
compiler's own checked arithmetic before any of the new arrays could be laid
out. The count is formed against an int64 rather than converted after the
fact. Every caller either compares two of them or was already int64 —
`LlSize`'s product, `OpInt`, and two `write`s of a width — so the widening is
confined to the one function and its declaration.

**`verify/iso.py`'s `index_span_is_representable` becomes `<=`**, in this
commit, ADR-0013's rule being that the model moves with the lowering. All 48
rules still prove, `accepted-index-selects-the-right-element` among them.

`array [integer] of T` stays refused, and now on the correct ground: its span
is `2 * maxint`, which is not a value of the type.

## What this is evidence of, and what it is not

`tests/index_span.pas` is the case, and it fails without the change with the
diagnostic on all three of its type-definitions. It carries the three
spellings that span exactly maxint, because Sema's test is *rearranged* to
stay inside the integer type — `hi > maxint + lo` rather than
`hi - lo > maxint` — so the shape below zero is a second thing that could be
wrong, and `-maxint..0` and `-1..maxint-1` are where it would show.

**One of the three is allocated and indexed and the other two are not**, which
is a limit worth stating rather than hiding. Maxint + 1 components is 2 GB at
one byte each, and no smaller element exists — so *every* array this change
newly admits is at least that, a variable of one would not survive the
linker's small code model (`doc/implementation-defined.md` §6), and one
allocation is what the case can afford to make. `-maxint..0` is the one worth
spending it on: its lower bound is where `i - lo` reaches exactly maxint, the
largest offset the relaxed bound admits and the value that would wrap if the
bound were relaxed one step further. The emitted IR is
`sub i32 %i, -2147483647` into a `[2147483648 x i8]`, and the case indexes
both ends and traps one past.

The two mutations kill it differently, which is why both halves are here.
Restoring `>=` in Sema fails it with the diagnostic; narrowing `TypeLength`
back to `integer`, with the relaxed bound in place, fails it with
`runtime error: integer overflow in +` **from the compiler** — ADR-0287's
crash, moved one function along. The compiler built and ran ordinary programs
under both.

**The third mutation is the one that found nothing, and that is the finding.**
With `iso.py` returned to `<` and the compiler left relaxed — the model now
describing a stricter compiler than the one that exists — `verify.py` still
reports 48 rules and no gaps. A precondition is a hypothesis, and narrowing a
hypothesis only makes a proof easier; nothing in `verify/` compares one
against the Sema check it claims to restate. So the `iso.py` half of this
change is required by ADR-0013 and by honesty, and is enforced by neither.
`doc/sop.md` §7 carries that, restated from ADR-0288's row.

## Consequences

**A bound that is off by one in the safe direction is the hardest kind to
find.** Nothing fails, no program misbehaves, and every oracle agrees —
including the formal one, which agreed *because* it had been written from the
same reading. What exposed it was not a test but a comparison between two
refusals that could not both be capacity limits.

**A processor limit has to be a limit of the processor.** Refusing
`array [0..maxint]` was defensible only as a capacity, and a capacity that
admits a larger object elsewhere is not one. `doc/implementation-defined.md`
§6 is edited to state both bounds as they now are.

**The language accepts more than it did**, so this is a language change and
not a repair: programs this compiler refused yesterday compile today. It
needs no spelling and no clause of `doc/afterschool-pascal-spec.md` — AP 5.1
i) puts representation, storage layout and the limits that follow from them
outside that document, and this bound is one of those.
