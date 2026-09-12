# ADR-0414: An implementation is for a name the type was given, not one it was lent

## Status

Accepted.

## Context

ADR-0413 refused an inherent-implementation for a type **produced from a
schema**, on the argument that 6.4.7 interns a production by its tuple, so
`string(255)` is one type everywhere and routines of its own would be routines
of every `string(255)` in the program.

Measuring the rest of `lib/` for conversion found the same defect one step
over, and this one was not refused. `lib/dialect/pastime.pas` declares

```pascal
DayNumber = integer;
```

which is a type-definition whose denoter is a type-*identifier*: it creates
nothing and makes `DayNumber` a second name for the type `integer` already
denotes. `impl DayNumber` was **accepted**, and the probe says what that
means:

```pascal
type DayNumber = integer;
impl DayNumber;  function Weekday(d: DayNumber): integer; ...  end;
var plain: integer;
begin plain := 9; writeln(plain.Weekday:1) end.   { prints 2 }
```

A plain `integer` gained the method. ADR-0413's rule does not reach it: the
type object for `integer` has no schema, so the production test answers no.

**The first rule written for this was wrong, and the corpus said so.** It
refused any identifier whose definition did not *create* a type, which
refuses `impl integer` as well — and `tests/dialect/methods.pas` has written
one since ADR-0315, deliberately, as the case that a receiver need not be a
record. That failure is what located the real distinction.

## Decision

**An inherent-implementation shall be written for a name the type was given,
not one it was lent.** An identifier whose own type-definition is a
type-identifier may not carry one; `impl integer` may, and so may any
identifier whose denoter writes a record, a pointer, a handle or an
enumeration out.

The point is not ownership and not uniqueness — 6.7.10's
one-implementation-per-program rule (ADR-0413) already governs both, and would
refuse a second module's `impl integer` perfectly well. The point is that
`impl Day` **conceals** what it claims. A reader of that line has to follow
`Day` to its definition to discover that every integer in the program is
affected, and the name was chosen precisely because the author was thinking
about days. The diagnostic therefore names the identifier that would have to
be written instead:

```
'day' renames integer rather than defining a type, so an implementation here
would be one for every use of integer; write it for that name if that is what
is meant
```

**What the three refusals now share.** A subrange cannot carry one because
6.7.10.2 asks `Base()` and the host would be selected; a production cannot
because 6.4.7 interns it and no component owns it; a renaming cannot because
the claim would not be visible where it is written. They are three reasons and
one sentence: an implementation is for a type a component can be said to have
**named**.

The mechanism is a boolean on the symbol, `renamesType`, set at the
type-definition — the one place holding the denoter beside the name — and read
at the implementation. It is a property of the *name* and not of the type,
which is the whole content of the decision: `Day` and `integer` denote one
type and only one of them is a name that type was given.

## Consequences

- `doc/afterschool-pascal-spec.md` 6.7.10 gains the requirement and NOTE 11c.
- `tests/dialect/methods_errors.pas` holds the refusal; `tests/dialect/methods.pas`
  holds the other direction, `impl integer` still compiling and still chaining.
  The golden was regenerated and the only new line is the refusal.
- `lib/dialect/pastime.pas` keeps its exported names. It was never a candidate
  — 2 of 35 — and this is now the reason rather than the measurement.
- Nothing else in the tree declares a renaming it wanted to implement, so no
  library changed.

## Alternatives rejected

**Refuse any identifier whose definition does not create a type.** The first
attempt, and it refuses `impl integer`, which ADR-0315 admitted on purpose and
`methods.pas` pins. A rule that takes a tested facility away to close a
clarity hole is the wrong trade, and the corpus caught it within one run.

**Leave it to the one-implementation-per-program rule.** Sound on ownership
and silent on legibility: `impl Day` would compile, every integer would gain
the method, and the first person to notice would be whoever wrote
`n.Weekday` on something that is not a day.

**Make `T = integer` a distinct type instead.** That is a much larger
decision — nominal typing over an existing type — and it is the same question
the string-typed modules raise (`doc/history.md`). It would close this hole as
a side effect, which is a reason to record the hole now and not to design that
feature in a hurry.
