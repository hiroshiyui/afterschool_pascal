# 34. The variant-part-completer is an arm with no labels

Date: 2026-08-10

## Status

Accepted.

## Context

ISO/IEC 10206:1991 §6.4.3.3 lets a variant-list end with a
variant-part-completer:

```pascal
case kind: shape of
  circle: (radius: integer);
  square: (side: integer);
  otherwise (sides: integer)
end
```

It is the second Extended Pascal feature (ADR-0033 was the first) and the other
half of the same word-symbol. The question is what it *is*: a fourth thing a
variant part can hold, or an arm like the others.

ADR-0018 laid a variant part out as one block of shared storage with each arm a
struct laid over it, and ADR-0026 made an arm's field-list a field-list — so an
arm may hold a variant part of its own, and a field's `variant` is the *path* to
its field-list rather than one index. Nothing in either of those consults an
arm's labels. The labels decide only *which* arm a tag value names, and the
compiler asks that question in exactly one place.

## Decision

**The completer is an arm whose label list is empty**, flagged `isOtherwise` in
the tree and in the type. It is numbered with the others, gets its path like the
others, and its fields are added to the record like any other arm's. There is
**no codegen change at all** — the layout, the field numbering, `fieldsAt`,
`armsAt`, `fieldAddress` and `selectedSize` are untouched, because none of them
ever read a label.

An empty label vector would have said the same thing in a program with no
errors. The flag exists because a label that fails to evaluate is dropped, so
"no labels" is also what a *broken* arm looks like, and a diagnostic must not
turn one into the other.

**The one place labels are read is `new(p, c1, ..., cn)`** (ISO 7185 §6.6.5.3),
and that is the one place this changes: a tag value claimed by no labelled arm
now selects the completer instead of being the error "no variant is selected
by". The value must still be a value of the tag type — that is all the
completer promises about it.

**Nothing may follow the completer.** §6.4.3.3 puts it at the end of the
variant-list, so the parser ends the list there, exactly as the otherwise-part
of a case statement ends its arm list. An arm after "everything else" could
never be selected.

**Telling it from an ISO 7185 identifier is one token of lookahead**, as it was
for the statement — but a *different* token. A case label is followed by `:`,
`,` or `..`; a variant's label list by `:` or `,`; and the completer by `(`. So
the variant-part form looks for `(` where the statement form looks for the
absence of the other three. `tests/iso_identifiers.pas` now runs both legal ISO
7185 programs — a case label and a variant label, both naming a constant called
`otherwise` — which is what stops either lookahead being "simplified" into the
other.

## Consequences

**No trap, and nothing to prove.** A case statement without an otherwise-part
traps on an unmatched selector; a variant part has no such obligation, because
ISO 7185 never checked that a field belongs to the selected variant and this
does not start. The completer therefore adds no run-time check, no `verify/`
rule, and no failure mode — it makes an existing *compile-time* error go away
and nothing else.

**A variant part with only a completer is accepted**, though the grammar
requires at least one labelled variant before it. This is laxity of the same
kind ADR-0033 already declared for word-symbols not yet reserved: it accepts a
program a conforming processor would reject. Rejecting it would need a rule
whose only content is "at least one", and no program is served by it.

**Nine mutations, nine caught — after the ninth found a harness bug rather than
a compiler one.** Three escaped on the first run, and two of those were
`standard_of` in `difftest.sh` and `irtest.sh`: the pattern `*/tests/extended/*`
does not match the *relative* path a file named on the command line arrives as,
so both compilers were told `iso7185`, both rejected the program with the same
message, and the diff was clean. A green result meaning the question was never
asked — the same failure mode ADR-0033 recorded, from a different direction, and
the reason to distrust a mutation harness that reports nothing.

The third escape was real and is now `tests/extended/variant_after_otherwise.pas`:
no file in the corpus had anything after the completer, so removing the rule
that ends the variant-list there changed no output.
