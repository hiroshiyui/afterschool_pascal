# ADR-0118: A sum type is a variant record whose tag cannot lie

## Status

Accepted. The first feature admitted to `--std=afterschool`, and the record
ADR-0117 said would have to argue for one on its own merits.

It decides the *rule*. The implementation lands separately, and this record is
what that commit is held against.

## Context

Three increments of `lib/` produced one recurring shape: every routine that can
fail invents its own way of saying so. `TryParseInt` answers a boolean and
writes through a `var`, `MapGet` takes a `whenAbsent` value, `VecNew` clamps a
bad capacity in silence. Three shapes for one missing thing, and the reason none
of them *reports* is that a library here may not halt — §6.9.1's read of an
integer is an error when the text is not a number and stops the program
(ADR-0076).

The obvious answer is a sum type. The useful discovery is **how much of one
already exists**, measured rather than assumed:

| | |
| --- | --- |
| a tag beside overlapping payloads | already there (ADR-0027) |
| variant labels exactly covering the tag type | already there (ADR-0096) |
| strings, records and arrays as payloads | work |
| `case` over the tag | works |
| one function's result handed to another as a value | **was refused**, now fixed |
| the tag assigned independently of the payload | **unchecked** |
| reading a field of an inactive variant | **unchecked** — §6.5.3.3, Annex D.2 |

A `Result` already runs in plain Extended Pascal today. So this is not a new
construct; the gap is two lines of the table, and both are *errors* in the ISO
sense rather than gaps in expressiveness.

### Why that distinction is the whole design

§3.1 makes an **error** a violation a processor is permitted to leave
undetected, and `doc/implementation-defined.md` §3 lists D.2 among the ones this
compiler deliberately does not report: *"Reading or writing a field of a variant
that is not active … the rule for a variable has never been checked."*

A conforming program therefore **never** reads or writes an inactive variant. So
detecting it changes the meaning of no correct program — which is exactly what
ADR-0117's containment claim needs, and it is why this feature fits the dialect
without weakening the promise that every Extended Pascal program is a valid
Afterschool Pascal program meaning the same thing.

That constraint is load-bearing and it rules designs out. It is the reason the
tag does **not** become read-only: `v.tag := isReal` is legal today and §6.4.3.3
gives it a defined meaning — it activates whichever variant the value selects.
Refusing it, or making it not do that, would break a conforming program, and no
amount of added safety would buy that back.

## Decision

**In `--std=afterschool`, §6.5.3.3's error is detected, and a write decides
which variant is active.** Two rules:

1. **Assigning to a field of a variant makes that variant active** — the tag is
   stored as part of the assignment. `r.num := 5` sets the tag to `ok`.
2. **Reading a field of a variant that is not active traps**, the way an array
   subscript out of bounds does (ADR-0017) and a `case` with no matching label
   does (ADR-0018).

Together those make the tag authoritative: it cannot disagree with the payload,
because the only way to write a payload is through the thing that sets it.

```pascal
type Outcome = (ok, bad);
     ParseResult = record
       case tag: Outcome of
         ok:  (num: integer);
         bad: (message: string(64))
       end;

{ construction needs no tag assignment, and cannot get it wrong }
r.num := 42;              { tag becomes ok }
r.message := 'no';        { tag becomes bad }

case r.tag of             { already exhaustive over Outcome, ADR-0096 }
  ok:  writeln(r.num);    { permitted -- tag says ok }
  bad: writeln(r.message)
end;

writeln(r.num)            { traps when the tag says bad }
```

**No new syntax, no new word-symbol, no new type constructor.** That is the
point rather than a saving: the construct is the one both standards already
have, spelled the way they spell it, which is CLAUDE.md's standing rule for a
dialect feature. What the dialect adds is that the construct tells the truth.

### Activity is a chain, not a flag

A variant part may nest, and an inner tag stays readable when the arm containing
it is not active — probed, not assumed. So "is this variant active?" is a walk
from the field outward: reading `v.p` requires the outer tag to select `two`
*and* the inner tag to select `xx`. The check follows the same path
`addressOf` already walks, and asks one comparison per variant part crossed.

### A tagless variant part is left unchecked, and that is a hole

§6.4.3.3 permits `case Kind of` with no tag field, and this compiler accepts it.
There is then no tag to make authoritative and nothing to compare against.

Three answers were considered:

- **refuse it in the dialect** — rejected. It would break ADR-0117's
  containment: a conforming Extended Pascal program using a tagless variant
  would stop compiling, and the containment claim is worth more than closing
  this case;
- **synthesise a hidden tag** — rejected for now. It changes the record's
  layout, which reaches `LlSize`, `new(p, c1, …, cn)`'s variant selection
  (ADR-0027) and every whole-variable copy. That is a representation change and
  wants its own record;
- **leave it unchecked and say so** — taken.

So a tagless variant part in the dialect behaves exactly as it does in the
conformance modes: an untagged union, unchecked. It goes in `doc/sop.md` §7 as
a hole in a safety claim, because a safety feature with an unstated exception is
worse than none.

## Consequences

- **The cost is one comparison per variant-field access, in the dialect only.**
  The conformance modes emit exactly what they emit now, and the existing corpus
  is what proves it.
- **`lib/` does not change in this increment.** The library is written in
  Extended Pascal and stays so; rewriting `TryParseInt` and `MapGet` against a
  `Result` would make the library dialect-only, which is a decision about what
  the library *is* and belongs in its own record.
- **Sema already has what the check needs.** Every record's field/variant
  numbering is decided and shown by `--dump-sema`, so CodeGen is told which
  variant a field belongs to rather than deriving it — the contract in CLAUDE.md
  holds unchanged.
- **`verify/` gets a rule.** The trap fires exactly when the tag does not select
  the field's variant, and that is a property statable over the tag and the
  variant numbering rather than a restatement of the emitted comparison. A rule
  that merely re-emitted the test would dilute "no known gaps" (ADR-0013).
- **difftest cannot see any of it.** `src/` is frozen at the conformance surface
  (ADR-0117), so the dialect corpus is compared by no second implementation.
  `irtest.sh` runs it, goldens cover it, and `verify/` covers the trap.

## What this does not do

- **No exhaustiveness requirement on a `case` *statement*.** `case r.tag of`
  with an arm missing still traps at run time rather than failing to compile.
  §6.4.3.3 already makes a variant *part* cover its tag type (ADR-0096), so the
  declaration is exhaustive and only the statement is not. Making it a
  compile-time requirement is a separate feature with its own cost — it needs a
  rule for `otherwise`, and it would change what a conforming program means.
- **No payload-binding form.** There is no `case r of ok(n): …` that binds the
  payload to a name; the arm reads `r.num`, and the check is what makes that
  safe. A binding form is sugar over this and can be added later without
  changing the representation.
- **No optional type and no non-nullable pointer.** ADR-0109 lists those under
  the memory-safety model, which stays open.
- **No `Result` in the standard library**, per the consequence above.
- **Nothing about tagless variant parts**, per the hole above.
