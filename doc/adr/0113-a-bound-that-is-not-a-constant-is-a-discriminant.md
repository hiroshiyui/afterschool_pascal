# ADR-0113: A bound that is not a constant is a discriminant

## Status

Accepted.

## Context

ISO/IEC 10206:1991 §6.4.2.4 writes

    subrange-bound = expression

where ISO 7185 §6.4.2.4 writes `subrange-type = constant '..' constant`, and
§6.2.3.8 b) puts "each actual-discriminant-part **or subrange-bound** not
contained by a schema-definition and closest-contained by … the block" in the
block's commencement — ordered *after* the attribution of the formal value
parameters. So

```pascal
procedure p(m: integer);
var a: array [1..m] of real;
```

is a legal Extended Pascal program, and this compiler refused it with *the
bounds of a subrange must be ordinal constants*.

ADR-0107's second independent reading found it and called it the finding most
likely to break a real program. `doc/implementation-defined.md` §6 has carried
it since as unfixed rather than chosen, and `doc/sop.md` §7 as a live gap.

The obstacle recorded there is exact: the per-variable descriptor ADR-0041
built is **keyed on a schema**, and a bare array bound has none. Everything
downstream of a dynamically sized variable asks a schema for something —
`IsGeneric` is "a schema and no tuple", the descriptor is laid out from
`descSchema^.discs`, the domain check and the size walk are handed one. Twelve
sites in CodeGen and about eighteen in Sema, in each of the two front ends.

What was *not* missing was the type representation. `ResolveSubrange` already
had a dynamic branch carrying `loDisc`/`hiDisc` — a bound read from a
descriptor slot — because a schematic formal parameter needs exactly that, and
CodeGen already lowers it. The offer of a descriptor was simply never made to a
denoter that was not a schema-name: `CheckVarDecl` set `dynamicVarFor` only
when `g^.grType^.kind = nkSchema`.

## Decision

**A subrange-bound of a variable's own type-denoter that does not fold becomes
a discriminant of that variable**, and the variable is given an **anonymous
schema** to hang it on.

- `dynBoundsFor` is the offer, made to the first name of a variable-declaration
  group under `--std=extended` and withdrawn on the way to any type that is not
  the variable's own — an array's index-type and component-type keep it, so
  `array [1..m] of array [1..k] of real` is one variable with two
  discriminants; a record field, a file component, a set base and a pointer
  domain do not, because their storage is not this variable's to size.
- `EvalBound` gains a third form. A schema body's bound must *name* a
  discriminant, because there the tuple is the caller's and only a name can
  reach it; a variable's bound may be any ordinal **expression**, because it is
  evaluated on the spot and nothing else needs to know how it was written.
- `BoundSchemaFor` gives the variable a schema symbol with **no body and no
  name**, whose discriminants are the symbols just created. That makes
  `IsGeneric` true and every keyed-on-a-schema site work unchanged.
- Each name of the group gets its own descriptor, so the denoter is resolved
  again per name — the same shape the schema group already had, and for the
  same reason: two descriptors cannot share a type however alike they look.

**The synthetic schema needs no body**, which is what made this small. A schema
keeps its *syntax* so a second type can be produced from it for a second tuple;
nothing produces a second type here, the only type it describes being this
variable's, and nothing looks it up, the program having never written it. What
a schema is needed for at this point is the list of discriminants a descriptor
is laid out from.

**Its emptiness is load-bearing in one place.** `CheckSchemaDomain` reports a
tuple outside §6.4.7's domain by naming the schema; for `array [1..m]` with
`m = 0` there is no schema to name, so a zero-length spelling selects a message
describing the array instead — *this array has no components: its upper bound
is below its lower bound*. Naming `$anon1` would name something the source does
not contain, which is the mistake ADR-0074 is about.

**ISO 7185 does not get this.** The offer is not made under `--std=iso7185`, and
a bound that is not a constant is the error it has always been.
`tests/dynbounds_iso.pas` is the same program refused.

## Consequences

**A program that was refused is now accepted**, which is the point. It is
recorded in `CHANGELOG.md` under `Added` rather than `Changed`: no program that
compiled before compiles differently.

**A module's variable may not have one**, for the reason ADR-0041 already gave
about discriminants — §6.2.3.6 makes a module's activation last as long as the
program, so there is no stack for storage sized on entry. The two are one rule
and are two messages only because each names what the program wrote;
`tests/extended/module_sema_errors.pas` carries both.

**The bound is evaluated once, at commencement.** A later assignment to `m` does
not resize `a`, which is §6.2.3.8 b) and not an implementation shortcut.

**Where the offer is not made, the message is the old one.** A type-definition
and a record field still refuse a non-constant bound
(`tests/extended/dynbounds_errors.pas`). The first is `type t = array [1..m] of
integer`, and it is the other half of §6 — the descriptor would belong to the
*block* and be shared by every variable of `t`, where descriptors are
deliberately per-variable, so it is a second decision about ownership rather
than a continuation of this one. It stays in
`doc/implementation-defined.md` §6.

**What this does not do.** It does not report a bound that reads an
uninitialised variable. `var n: integer; a: array [1..n] of integer` is accepted
and `n` is undefined when the bounds are evaluated — §6.5.1's undefined-value
error, which this processor already leaves unreported (§3 of the same document).
Nothing new is wrong here; it is newly *reachable*, which is worth knowing.

It also leaves `verify/` untouched: the bounds check the lowering emits is the
one ADR-0017 already proved, with the bounds read from a descriptor rather than
from the type. No lowering rule changed, so the commit carries
`Model-unchanged:`.

## Alternatives rejected

**Widen `isGeneric()` with a second marker.** The information is already in the
type — a subrange with `loDisc`/`hiDisc` is dynamically bounded — so a flag
would have done without inventing a schema. It would also have put a
null-schema path into every one of the thirty-odd sites that ask a generic type
for its schema, in both front ends, for a narrow feature. The anonymous schema
buys all of them unchanged.

**Desugar the denoter into a real schema, with a body and named formals.** The
first design, and it is what the word "anonymous schema" suggests: rewrite
`array [1..m]` into `S($b0) = array [1..$b0]` and instantiate it. It needs node
surgery in Sema, synthetic pool names, and the *same* surgery in both front
ends so the Sema dumps agree — and none of it is needed, because nothing ever
resolves the body.

**Attach the bound expressions to the variable as a list**, matching
`discExprs`, rather than putting one on each discriminant. The list would have
to be built from nodes the parser did not chain, and the group's second and
later names re-resolve the same denoter — so the chaining would happen more than
once over the same nodes. One expression per discriminant has no such state.

**Accept it in a type-definition too.** That is §6.2.3.8 b) as well, and
refusing it is a gap rather than a reading. It is left out because it is a
different decision — who owns the descriptor — and because bundling the two
would have made this change untestable as one thing.
