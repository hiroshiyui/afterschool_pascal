# 215. A type-inquiry-object is a variable-access

Date: 2026-08-27

## Status

Accepted. AP 6.4.9.

## Context

ADR-0214 struck a roadmap entry that had called this a conformance gap. It is
not one: ISO/IEC 10206:1991 §6.4.9's type-inquiry-object is

```
type-inquiry-object = variable-name | parameter-identifier .
variable-name       = [ imported-interface-identifier '.' ] variable-identifier .
```

— a **name**. What was left when the false claim was removed was a real wish
with a real caller, and it became open question 4 of `doc/roadmap.md`. This
record answers it.

**The caller is `lib/dialect/pascontainer.pas`.** ADR-0211 gave a routine a type
parameter and ADR-0213 gave a pointer domain type discriminants, so one
container body serves every element type. What neither gave was a way to *read*
the element type off the container, so eight of its headings took the same fact
twice:

```pascal
procedure VecPush(Ptr: type; Elem: type; var v: Ptr; x: Elem);
```

`Ptr` is `^Vec(integer)`, which already says `integer`. `Elem` is that word
written again, and a call that disagreed with itself — `VecPush(IntVec, char,
…)` — was refused only where the argument was finally assigned.

## Decision

**Under `--std=afterschool` the type-inquiry-object is §6.5.1's whole
variable-access.**

```pascal
procedure VecPush(Ptr: type; var v: Ptr; x: type of v^.a[1]);
```

### It is spelled by widening a position, not by taking one

ADR-0140's test is whether a conforming program could have written the
construct in that position. `type of` is a position the dialect already holds
in both conformance modes, and what follows `of` was a name; a bracket, a caret
or a second period after that name is a syntax error under
ISO/IEC 10206:1991 and stops ISO 7185 one token earlier still. So this reserves
no word-symbol and adds no marker.

**It is ADR-0184's shape, and the second feature to take it**: a rule about
what is admitted at a position the dialect already holds, rather than a
construct of its own. ADR-0184 admitted a record at an `external` heading;
this admits a selector chain after `type of`. Both inherit an existing
spelling, which is why `grep 'type of'` still finds every use.

### The object is parsed by the production designators are parsed by

`ParseSelectors` builds it — the same loop `a[i]`, `p^` and `r.f` go through in
an expression. That decides the one genuine ambiguity for free. §6.5.1's
variable-name admits a period before an *imported-interface-identifier*, and
`r.f` over a record is a field-designator; the two are spelled identically and
only the symbol tells them apart, which is what `fdQualified` has existed for
since ADR-0053. **Ask the symbol, not the syntax**, for the sixth time — and
here it is not a new application of the rule but the reuse of an existing one,
since the expression parser had already met this exact ambiguity.

**A bare name is put back where §6.4.9 keeps one**, in `tqAt`/`tqLen`, and
`tqObj` stays nil. Every rule the clause already had is written against those
two fields, so a conforming program under `--std=afterschool` takes the path it
takes under `--std=extended`, instruction for instruction. That is containment
by construction rather than by sweep — `dialect-containment` confirms it over
219 sources, but it could not have failed.

### What it refuses, and what it deliberately does not

| written | answer |
| --- | --- |
| `type of c[1]`, `c` a constant | *'type of' names a variable-access, and this is not one* |
| `type of s[1..3]` | *a substring possesses the canonical string-type…* |
| `type of s`, `s: array of integer` | refused as before — a slice cannot be named |
| `type of s[1]`, same `s` | **`integer`** |

The last two are the extension working rather than an inconsistency. AP
6.7.3.9.2 confines a slice type to a formal parameter's own denoter, so
`type of s` names a type that may not exist there (ADR-0143); `s[1]` names one
that exists everywhere.

**Neither the slice refusal nor the schematic-formal refusal is repeated on the
access path, and that is a claim rather than an omission**: a selector cannot
produce either. A slice type may be written only as a formal's own denoter, so
no field, element, domain or buffer has one; and a type with no discriminant
tuple belongs to a formal parameter, so no component has one either. Where the
checks would have gone, the code says why they are not there.

**The substring is the one variable-access this denoter cannot answer for.**
§6.5.6's substring-variable *is* a variable-access, and what it possesses is
§6.4.3.3.1's canonical-string-type — `hi` negative, a pointer and a length with
no storage. No variable may have it; `var x: string` is refused one clause
earlier for exactly this reason. It was found by writing the case: the program
compiled, ran, and stopped at *a string of length 3 does not fit a capacity of
0*.

**A function-access needs no refusal because it cannot be written.** The
selector production has no `(`, so `type of f(1)` never becomes a call node;
the constant-access above is what actually reaches `IsDesignator`.

### The object is not evaluated

§6.4.9 requires it of a name and AP 6.4.9 requires it of everything the access
contains. This costs nothing to honour and nothing to implement: **the type of
`a[i]` does not depend on `i`**, so the index is checked for its own
well-formedness and its value is never wanted. A type-denoter is Sema's and
CodeGen never walks one, so there is no path on which it could be evaluated.
`tests/dialect/typeinquiry_access.pas` names a function in a type-denoter and
prints the call count, which is nought.

### §6.4.9's own restrictions move to the root

A variable-access has a root and the root is a name, so the two rules the
clause already carried are the same question about the same symbol:
§6.4.9's own — a parameter-identifier's defining-point must be in the
closest-containing formal-parameter-list — and §6.7.3.1's prohibition on an
applied occurrence of the parameter-identifier, which now refuses
`x: type of x^.f` as it always refused `x: type of x`. One predicate and one
root-name helper serve both shapes.

### Re-instantiation needed nothing, and the reason is worth recording

ADR-0211's instantiation re-checks a generic's *shared* heading denoters after
`ForgetResolved`, and the fear was that a designator inside one would carry the
previous instantiation's symbols into the next. It does not: `ResolveType`
caches on `d^.ntype` and `ForgetResolved` clears exactly that, and `CheckExpr`
resolves `vrSym`, `fdResolved` and `fdQualified` **unconditionally** rather
than consulting what is there. So clearing the inquiry denoter's own type is
the whole of what re-instantiation requires. The evidence is a case, not the
argument: `typeinquiry_access.pas` instantiates one body over `integer` and
over a record and reads a different element type each time.

## Consequences

**The library lost five type parameters and kept two, and the two say where
this stops.** `VecPush`, `VecPop`, `VecSet`, `VecReserve` and `MapPut` no
longer take the element type. `VecGet` and `MapGet` still do, because they
*return* it and ISO/IEC 10206:1991 §6.7.1 makes a result-type a `type-name`:

```
result-type = type-name .
```

A type-inquiry is not a type-name, so `function VecGet(…): type of v^.a[1]` is
unwritable — in the dialect too, this record having widened one production and
not that one. Whether AP should widen `result-type` as well is a question of
its own and is not answered here; it wants the same argument made again about a
different clause, and the two-parameter form still works.

**Four cases and one component are new**, and one of them exists for a single
branch: `typeinquiry_import.pas` imports a module to write `type of
TqMod.Origin.x`, which is the only way to spell a qualified name *and* a field
selection in one object. Nothing else reaches the root-name helper's second
arm, and `line-coverage` is what said so — three statements, named.

**Annex B gains a row and `containment_exceptions.txt` gains four.** The row is
mechanical. The four are not, and they are the first construct here whose
refusal takes more than one file: the parser stops at its first error and this
construct has three tokens that can start it, so three spellings are three
programs, and the fourth — `type of r.f` — is refused a stage later by Sema
because the parser cannot tell it from a qualified name.

**Cost.** One AST field, one parser branch, one Sema function, one predicate
extracted, one root-name helper. The conformance modes' refusal now names the
mode (ADR-0154) in both front ends, which changed three goldens landed the day
before.

**What was rejected.**

*Widening the object under `--std=extended` too* — that is the defect ADR-0214
described, inverted.

*Keeping `ParseQualifiedName` under the dialect and building a designator only
when a selector follows* — it splits `type of r.f` from `type of r.f[1]`, since
the first has no selector to trigger the second path, and would have needed
Sema to convert one shape into the other. One production for both is what the
expression parser already does.

*Requiring the index-expression to be nonvarying* — it would refuse
`type of a[i]` for no gain. The value is never read, so there is nothing for a
restriction to protect.

*A `type of` over a function-access, spelled `type of f(1)`* — §6.8.6's NOTE
says a function-access is not equivalent to a variable-access, and the result
type of a function is already writable as its own name. Nothing asked for it.

*Widening `result-type` in the same record* — see above. A second production is
a second decision.
