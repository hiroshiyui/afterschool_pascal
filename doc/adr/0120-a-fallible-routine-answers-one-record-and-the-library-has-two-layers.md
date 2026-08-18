# ADR-0120: A fallible routine answers one record, and the library has two layers

## Status

Accepted. It takes the question ADR-0118 parked — whether `lib/` should be
rewritten against a result type — and answers it in a way ADR-0119 had already
narrowed to one option.

## Context

Three increments of `lib/` produced the finding ADR-0118 recorded: every
routine that can fail invents its own way of saying so.

| routine | how it reports |
| --- | --- |
| `PasText.TryParseInt` | `boolean`, value through a `var` |
| `PasMap.MapGet` | a `whenAbsent` value the caller supplies |
| `PasVector.VecNew` | clamps a bad capacity, silently |

Three shapes for one missing thing, and none of them *reports*, because a
library here may not halt: §6.9.1's read of an integer is an error when the text
is not a number and stops the program (ADR-0076).

Two of those shapes share a defect that is not obvious from the table. A
`boolean` plus a `var` leaves the value in existence whether or not it was
parsed, so nothing stops a caller reading it after a `false`; a `whenAbsent`
default cannot distinguish "absent" from "present and equal to the default".
Both are quiet.

ADR-0118 built the mechanism that fixes this — in `--std=afterschool`, a write
to a variant's field activates that variant, and a read of an inactive one
traps — and deliberately did not use it, because using it would decide what the
library *is*.

**ADR-0119 then removed the option that would have been unsafe.** The two rules
are a pair and both are emitted at the access, so a dialect module under
conformance-mode callers runs its guard against a tag nothing maintained and
passes an access that is wrong. A mixture no longer links. So a result type
cannot be introduced as a safe layer beneath the library as it stands; the
choice is between rewriting `lib/` into the dialect and adding something beside
it.

## Decision

### 1. The library has two layers, and they do not mix

`lib/` stays **Extended Pascal**, conformant and importable by any conforming
program. `lib/dialect/` is **`--std=afterschool` all the way down** — its
modules import only each other, and only a dialect program can link them.

Rewriting `lib/` was rejected. Its modules are the only Pascal in this
repository that a reader can take away and compile with another ISO/IEC
10206:1991 processor, and that is worth more than the safety, which is
available to anyone who wants it one directory over. It would also have made
the dialect's first real user its *only* user, which is the wrong shape for
something that has to earn its keep against a specification.

The cost is stated rather than hidden: **the two layers duplicate.**
`PasParse.ParseInt` trims its own input rather than calling `PasText.TrimAll`,
because ADR-0119 will not link a conformance-mode module into a dialect
program. Where a dialect module needs something `lib/` already has, it gets its
own copy. That is a real price and it is the price of the containment being
enforced rather than promised.

### 2. A fallible routine answers one record: the result shape

```pascal
IntResult = record
  case ok: boolean of
    true:  (num: integer);
    false: (code: ErrorCode)
  end;
```

Three properties, and each is load-bearing:

- **The tag is spelled `ok` and its type is `boolean`.** §6.4.3.3 with ADR-0096
  requires a variant part's labels to be exactly its tag-type's values, and
  `boolean` has precisely the two a result needs. A three-state code as the tag
  would have to name every one of its values as an arm.
- **The failed arm carries an `ErrorCode`**, from `lib/dialect/paserror.pas` —
  the one part of the shape that *can* be shared.
- **Nothing assigns the tag.** `r.num := acc` is the statement that makes the
  result successful; `r.code := errSyntax` is what makes it a failure. There is
  no line to forget, and an explicit `r.ok := true` would be a second opinion
  free to disagree with the payload — which is the whole thing ADR-0118
  removes.

### 3. The shape is a convention, not a type, and it cannot be otherwise

With no generics, a result record's payload type is part of its layout, so
`Result` cannot be a library type: each producing module declares its own.
What is shared is `ErrorCode`, the spelling of the tag, and the rule that the
payload is written and never the tag.

This is the same wall ADR-0116 hit — `PasVector` holds integers and the
documented answer for another element type is to copy the file — and it is
worth recording that it was hit twice from different directions before anyone
proposes generics as a convenience.

## Consequences

- **A caller who does not check gets a trap, not a stale value.** That is the
  whole return, and `tests/dialect/trap_result_unchecked.pas` is what it looks
  like: the same mistake against `TryParseInt` reads an integer that was never
  parsed and the program carries on.
- **The trap is not a diagnostic and cannot be.** Nothing is wrong with the
  source; whether a read is legal depends on what was parsed. So the case
  carries a `.err` and a non-zero exit rather than a golden diagnostic.
- **`value` is not available as a field name.** ISO/IEC 10206:1991 §6.1.2
  reserves it as a word-symbol, so the obvious spelling of a result's payload
  is refused and each module names its own — `num` here. Worth knowing before
  designing a shape around it, which is how this was found.
- **`tests/run_test.sh` and `selfhost/irtest.sh` now translate a component with
  the components listed before it.** Each used to translate every component in
  isolation, so a component importing another could not build — which no case
  had needed, `tests/extended/components/` holding none that import a listed
  peer. `lib/dialect/pasparse.pas` imports `paserror`, and that is the case that
  fails without the harness change.
- **What this does not do.** It does not convert `PasMap` or `PasVector`; it
  does not add a result-carrying string, list or map type; and it takes no
  position on `case` as an expression or on exhaustiveness checking, which
  ADR-0118 also left open. One producing module is enough to hold the shape
  still while it is judged.
- **No second implementation sees any of it** (ADR-0117), and neither does the
  BSI suite. What covers it is goldens, the trap case, and `irtest.sh` — which
  does not skip the dialect.
