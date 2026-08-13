# 71. Five things the grammar admitted and the compiler refused

Date: 2026-08-13

## Status

Accepted.

## Context

A sweep of ISO/IEC 10206:1991's Annex A — all 274 productions, each probed with
a compiled program, and each also checked against the corpus for whether any
existing program writes it — turned up five constructs the standard admits and
this compiler rejected. None of them appeared anywhere in the 396-file corpus,
so every oracle agreed: the differential test compares two compilers that were
wrong in the same way, and the SMT rules and the bootstrap fixed point say
nothing about a construct no program contains.

They are unrelated to each other and each is small. What they share is how they
were found, and that is the reason for one record rather than five.

## Decision

**`char + char` is a two-character string** (§6.8.3.6). Table 7's operands are
"Char-type **or** the canonical-string-type" and the clause says "*a and b*", so
both may be char. The type rule carried an explicit `!(l->isChar() &&
r->isChar())`, present identically in both compilers and commented in neither.
Removing it takes nothing away: table 3 gives char no arithmetic `+`, so there
is no other reading to protect, and the `--std` gate already keeps ISO 7185's
integer `+` unaffected. Every other pairing — `char + string`, `string + char`,
`string + string` — already worked, which is exactly why this one was never
met.

**A qualified name may stand wherever a type-name may** (§6.11.3). `type-name`,
`schema-name` and `variable-name` all carry the optional
`imported-interface-identifier '.'`, and four positions read a bare identifier
instead: a pointer's domain (§6.4.4), a restricted type (§6.4.2.5), a
type-inquiry object (§6.4.9), and — through Sema rather than the parser — the
lookups behind the first two. One `parseQualifiedName` now serves all of them
and the type-name site that already had the code inline.

**A qualified name may also be the first bound of a subrange** (§6.4.2.4). This
was a different cause with the same symptom: `looksLikeSubrange` scans ahead for
a `..` to tell a subrange from a type name, and treated a `.` as the end of the
denoter — so `mi.lo .. mi.hi` aborted the scan while `1 .. mi.hi` worked. The
period now ends the denoter only when no identifier follows it. The program's
final `end.` is never reached, because `end` stops the scan a token earlier.

**A schema may be given a second name** (§6.4.7's first alternative,
`identifier '=' schema-name`). It is the same tokens as a type-definition
naming a type, so **the symbol decides and not the syntax** — the fourth time
that shape has been the answer here, after ADR-0044's variant-selector,
ADR-0053's qualified name and ADR-0066's set-value.

The two names must denote **one schema, not two alike ones**. §6.4.7 says the
identifier denotes "the schema denoted by the schema-name", and §6.4.8 keys a
produced type on (schema, tuple) — so a copy would make `vec2(3)` and
`vector(3)` distinct types and refuse an assignment between them. They
therefore share one `Symbol`: `bindName` puts an existing symbol under a second
name, which is the mechanism a `with` binding already used.

**A `with` may take a type produced from a schema** (§6.9.3.10). The clause
says the with-element "shall possess **either a type produced from a schema
or** a record-type", and then makes each of the schema's formal discriminants a
*schema-discriminant-identifier* for the region that is the statement. Both
halves were missing: `with v do` was refused outright for a non-record
production, and where the production *was* a record the fields resolved and the
discriminants did not.

- A region is a scope, so that is what it is: one scope over the body, one
  entry per discriminant.
- **Each entry denotes what `v.d` denotes, in each of the three shapes a
  produced type has** — and two of the three needed no symbol built. Where the
  tuple is constant the discriminant is a constant, so the entry is a `Const`
  holding the tuple's value. Where the type is generic — a schematic formal
  parameter — it is that parameter's own `Disc` symbol, the one `v.n` reads
  the descriptor through (ADR-0040). No node kind, no new lowering, and
  `n := 9` is refused by the message an assignment to any non-variable gets.
- **The third shape is the heap, and it is why the binding is a descriptor.**
  A heap variable's tuple is a header in front of it (ADR-0043) and `v.d`
  finds that header by walking *down* the designator to the whole variable —
  which a bare `d` cannot do, there being no designator to walk. So the
  binding, which exists to hold the address, holds the tuple as well: it
  becomes exactly the descriptor ADR-0040 gives a schematic formal, and the
  discriminants are `Disc` symbols of *it*. `addressOf` then reaches them by
  the walk every enclosing variable makes, and a `with` inside a recursive
  procedure sees the tuple of the variable its own invocation created.
  CodeGen's share is filling it: one store of the address into field 0 and one
  load per discriminant out of the header — from the address already computed,
  because §6.9.3.10 evaluates the element once.
- **A field may not share a discriminant's name — but only under a `with`.**
  §6.9.3.10 makes the field-identifiers *and* the discriminant-identifiers
  defining-points for one region, and §6.2.2.7 allows a region only one
  defining-point per spelling. Outside a `with` the same record is legal: the
  field's defining-point is for the record-type and the discriminant's for the
  enclosing type-denoter, and §6.2.2.5 makes the inner shadow the outer. So the
  error belongs to the statement, not to the schema, and the walk covers every
  arm of every variant part, an arm's field-identifier being one like any
  other. Without it `with v do writeln(n)` printed the *field* — uninitialised,
  so zero — while `v.n` outside the `with` read the discriminant: one name with
  two meanings depending on how it was spelled, and no diagnostic.
- **The diagnostic is worded by standard.** ISO 7185 has no schemata, so naming
  one there would offer a remedy that language does not have — the same reason
  `standardFileRef` words its message by standard.

**The trailing `;` after a variant-part-value** (§6.8.7.3). `field-list-value`
ends with `[ ';' ]` *outside* the alternation, so it may follow a
variant-part-value as well as a fixed part. The parser broke out of the loop
the moment it read one. It separates nothing — the `]` is next either way — so
accepting it is one call.

## Consequences

**The sweep is the finding, not the five fixes.** Each of these had been wrong
since the feature that introduced it, through every green run of a suite that
grew to 239 cases, because the corpus is what the oracles compare and the
corpus is smaller than the standard. `tests/extended/sweepgaps.pas` is the
entry that was missing; it exercises all five in one program, which is
defensible only because their common property is that nothing exercised them.
`withheap.pas` and `withschema_errors.pas` are separate because they pin
something else — a mechanism and a refusal that the sweep did not predict and
that only writing the feature found.

**Almost nothing needed a new mechanism** — the schema alias reuses `bindName`,
two of the `with`'s three shapes reuse `Const` and `Disc` symbols, and the
third reuses ADR-0040's descriptor rather than inventing a way to hold a
tuple. That is the usual sign that the features were already expressible and
only the rules were absent. The one genuinely new line of code generation is
the descriptor's fill, and it exists because the heap is the one place a
tuple has no name.

**Writing the `with` case uncovered a crash older than the feature.** A
designator rooted at a `with` binding, whose bounds belong to a heap variable —

```pascal
with g^ do cells[r, c] := 0
```

where `grid(r, c: integer) = record cells: array [1..r, 1..c] of integer end`
and `g: ^grid` — has been broken since ADR-0043. `heapHeader` walks *down* a
designator to the whole variable it selects from, and there is no node standing
for the record a `with` opened, so the walk stopped at the binding and the
bounds check was built on a null header. The binding's own type is what says a
header is there, so the walk now ends on it.

**The two compilers failed at different stages**, which is worth writing down
because it is the only visible trace the bug left. The C++ segfaults building
the bounds check. The Pascal one *compiles the program* and writes
`getelementptr i32, ptr , i32 0` — an empty operand, `WriteValue` having
printed a cleared string rather than dereferencing a nil pointer — so it fails
at `clang`, one stage further on and in a different tool. Same bug, same fix,
and no shared symptom to search for.

Both were broken, which is exactly why `difftest` was silent: it compares the
token, AST and Sema dumps, and both stages agreed down to the last line — the
fault is in a code generator `difftest` does not compare and that `irtest` had
no such program to run. That is the oracle asymmetry ADR-0025 accepted when it
chose to check CodeGen by *running* it, stated here as the shape of a real
miss rather than as a possibility.

**`verify/` gained nothing**, and correctly: there is no arithmetic, no
conversion and no check in any of the five. The only one that touches emitted
code at all is `char + char`, which routes to the concatenation the runtime
already performs for every other pairing.

### What this does not do

**A `with` over a schema-produced type still evaluates a binding it may not
need.** For a production with no fields and a constant tuple — `vector(4)` —
the hidden slot holding the address is unused, since the discriminants are
constants and there is nothing else to select. It is kept because §6.9.3.10
requires the element to be accessed once before the statement runs, and the
binding is what does that. On the heap the same slot is load-bearing, the
header being reached from the address it holds.

**A schema alias is not visible to a diagnostic.** The two names share a
symbol, so a message about `vec2(3)` names the schema `vector`. That is right
rather than a limitation — they *are* one schema — but it is worth knowing
before reading such a message as a mistake.

**`v.n` still prefers the discriminant to a field of that name**, outside a
`with`, which makes such a field unreachable. §6.8.4's discriminant-specifier
and §6.5.3.3's field-specifier have the same syntax and §6.2.2.6 excludes both
from the enclosing scopes, so the standard's own disambiguation is not
obvious; this record does not settle it. What it does settle is that the
program cannot then be written with a `with`, which is where the ambiguity
would otherwise have been silent.
