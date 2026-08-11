# 42. An assignment between two schematic types compares the tuples

Date: 2026-08-11

## Status

Accepted. It is the deferral ADR-0040 and ADR-0041 both named as the next small
one.

## Context

ISO/IEC 10206:1991 §6.4.6 gives assignment-compatibility six clauses, and the
one a schema type reaches is a): *T1 and T2 are the same type*. §6.4.8 makes a
schema a one-to-one mapping, so two types produced from one schema are the same
type exactly when they were produced with the same tuple. Where both tuples are
written in the program, that is already decided — the intern table ADR-0039
built answers it, and `assignable`'s `to == from` reads the answer.

What ADR-0040 and ADR-0041 added is a type produced *within an activation*,
whose tuple is not known until a caller brings it or the block computes it.
For those, "are these the same type" is not a question the compiler can answer
at all. §6.4.6 d) says what happens then:

> it shall be a dynamic-violation if T1 and T2 are produced from the same
> schema, but not with the same tuple

and §6.1's f) 2) permits a processor to report a dynamic-violation *during
execution* and terminate. So the standard does not give schema types a second
assignment rule; it gives the one rule a second moment at which it may be
applied.

## Decision

**The rule does not move — the comparison does.** `assignable` gains one case,
and it decides only what a compiler can decide: that both types were produced
from the same schema. Whether they are the *same* type is left to a run-time
comparison of the tuples, one `icmp` per discriminant, emitted where the
assignment is.

```
  if (to->isGeneric() || from->isGeneric())
    return to->schema == from->schema;
```

Two things this deliberately does not do. It does not weaken the case above it:
`vector(3) := vector(4)` is two known tuples and stays a diagnostic, which
§6.1's f) 1) explicitly allows. And it does not make the schema alone
sufficient — the tuple is still what decides, and it is still compared, just
later.

**Every discriminant is compared, not the ones a bound used.** §6.4.8 keys
identity on the whole tuple, so a discriminant the body never mentions still
distinguishes two types. That is why the comparison walks the *schema's*
discriminant list rather than the array's `loDisc`/`hiDisc`.

**One side may be a constant.** `discValue` answers "the k'th discriminant of
the tuple this expression's type was produced with" from whichever place holds
it — the variable's descriptor for a generic type, the `Type`'s own tuple for
every other. So `v := three` inside a procedure taking `var v: vector` compares
a loaded value against a literal, and needs no case of its own. The call-site
loop that passed a tuple to a schematic formal was doing this already and now
calls the same helper.

**Once the tuples agree the copy is the ordinary one.** ISO 7185 §6.8.2.2's
whole-variable copy with `dynSize` as its length and the *component's*
alignment — the same three parts ADR-0040's schematic value parameter already
assembled, for the same reason: the array type LLVM would be asked about has no
extent to give.

## Consequences

**The diagnostic for two known tuples got readable by accident.** Before this,
two schematic formals produced `cannot assign vec to a variable of type vec` —
both types print as the schema's name, because a generic type has no tuple to
name itself by (ADR-0040). That message is now unreachable for the case that
produced it, because the assignment is accepted; the ones that remain name
either two tuples or two schemata, and both read.

**The trap message is built by the runtime**, like `pas_index_error` and for
the same reason: the schema and the discriminant are named where the program is
compiled, and their values exist only where it runs. `pas_disc_error` takes
both halves.

**Twelve mutations on the C++ side and ten on the Pascal one, all caught —
after three escapes that named two missing tests, and both are about *which*
discriminant.** "Only the first is compared" and "the k'th is the first" both
need a schema with two discriminants *and* a tuple whose first agrees and
second does not, which is `tests/extended/trap_schema_assign_second.pas`. The
third, "only a generic destination takes the dynamic path", needs the known
tuple on the *left* and the unknown one on the right —
`trap_schema_assign_known.pas` — and it is the mutation worth keeping in mind,
because that version is not obviously wrong: it copies the right number of
bytes for the destination and simply never asks whether the source was that
type.

**No proof rule, for the third time in three records.** The comparison's ISO
condition *is* the emitted comparison — ADR-0013 says not to write a rule for
one of those, because it proves nothing and dilutes what "no known gaps" means.
The copy is `verify/`'s existing array reasoning with a length it already
quantifies over.

**A defect was found next door and is not fixed here.** Two generic *packed
char arrays* compare equal whatever they hold, because `emitStringCompare`
takes its length from `Type::length()` — `hi - lo + 1` on bounds that are
symbols, not numbers. It has been wrong since ADR-0040 and no oracle saw it;
the corpus had no schema producing a string. It is a wrong answer rather than a
missing feature, so it is a `fix` of its own rather than part of this.

## What this does not do

Of ADR-0039's five deferrals two remain, and neither is made easier by this:
a schema as the domain of a pointer with `new(p, discriminants)`, and a
discriminant as a variant-selector (§6.4.3.3). ADR-0040's other half also
stands — a schematic formal whose discriminants reach past an array, which is
the shape `string` itself has.

Relational operators on two schematic types are still refused, and this record
does not change that: §6.4.5's compatibility is a different rule from §6.4.6's,
and the only structured types with operators are the string types. What that
means for a schema *producing* a string is the defect above and then a decision
about `string`, not an extension of this one.
