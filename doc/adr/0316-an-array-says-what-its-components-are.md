# 316. An array says what its components are

Date: 2026-09-04

## Status

Accepted, 2026-09-04. Corrects the implementation of AP 6.7.3.10.4 c) and
widens that clause; amends
[ADR-0304](0304-a-prefix-of-the-type-arguments.md), whose feature this is.

Found by probe while settling
[ADR-0315](0315-methods-and-traits-without-inheritance.md)'s one open
technical question, and carried in `doc/roadmap.md`'s *Writing a daily
program* for as long as it took to write this.

## Context

`Determine`'s slice arm asked whether the actual's type **was already a
slice**:

```pascal
    else if d^.kind = nkArray then
      if (d^.arDims = nil) and IsSlice(t) then
        Determine(gen, d^.arElem, t^.elem, bs)
```

An ordinary array's type is not a slice — the conversion happens at the call,
and `tySlice` is a type CodeGen produces for a parameter and no program can
write. So for

```pascal
function Total(T: type; protected var xs: array of T): integer;
```

`Total(r[1..4])` determined `T` and `Total(r)` determined nothing:

    error: nothing in this call says what 't' of 'total' is: write the type
    arguments, or pass an argument whose type determines it

**The clause was already right, and this is the direction worth stating
plainly.** AP 6.7.3.10.4 c) reads the denoter after `of` "against the
component type of that actual-parameter" where the actual "is one 6.7.3.9.3
admits", and 6.7.3.9.3 admits *a variable denoting an array whose index-type
is an integer type*, a slice of one, or another slice. The whole array is
admitted, the non-generic `Plain(r)` over `protected var a: array of digit`
compiles and runs, and only inference could not read through it. The
implementation was narrower than the specification — not, as this was first
written down, the specification narrower than the parameter it describes.

**No oracle here could have said so.** `tests/dialect/generic_infer.pas` has
one slice activation and it passes a slice-designator, `lib/` has none, and
every gate that counts something counts a line or a procedure that *was*
reached. This is ADR-0304's own lesson a third time in the same feature: that
record found `MapGet` inferable and a header comment saying it was not, and
what settled it was four lines handed to the compiler rather than anything in
the tree.

## Decision

**An array-type determines a slice parameter's component type, as a slice-type
does.** The arm asks the two questions `CheckActualParams` asks of a slice
formal's actual and no third one:

```pascal
      if (d^.arDims = nil) and (IsSlice(t) or IsArray(t)) then
```

**Clause c) is widened, and to something wider than 6.7.3.9.3.** It now reads
against the component type wherever the actual possesses an array-type or a
slice-type, with no condition on the index-type, and NOTE 8 says why: an array
indexed by something other than an integer **determines** the type parameter
and is then refused as the actual it is, by 6.7.3.9.3's own rule and in that
rule's words —

    error: a slice can be taken only of an array indexed by integers, and
    array ['a'..'c'] of integer is not

— where excluding it here would have left the type parameter determined by
nothing and reported *that*, so the reader would have had to write a type
argument before the message they needed appeared. What the clause requires is
that there be a component type to read, and an array-type has one whatever its
index-type. **A category is a filter and this is not**: ADR-0266 refuses at the
instantiation because a constraint's whole value is a diagnostic at the call,
and the same argument here points the other way — determining and then
refusing is what puts the accurate message at the call.

**A variable-string still determines nothing**, having no component type in
this sense, and 6.7.3.9.3 does not admit one as a slice actual either:
`Plain(s)` and `Len(char, s)` for `s: string(8)` are both refused as *needs an
array or a slice of one, but the argument is short*. The two forms agreeing is
the property; a widening that made the generic form accept what the plain form
refuses would be the defect this record is about, written the other way round.

## Evidence

`tests/dialect/generic_infer.pas` gains the activation that could not be
written, beside the slice forms it is one instantiation with:

```pascal
  writeln(Total(r):1, ' ', Total(r[1..4]):1, ' ', Total(r[2..3]):1);
  writeln(Total(v):1, ' ', Count(g):1, ' ', Total(sub):1);
```

    100 100 50
    6 4 18

The second line is the surface, and **both of its new shapes were unreachable
while the arm asked for a slice**: `Total(v)` determines from the component of
a *schema-produced* array (`Vec(3)`), and `Count(g)` determines `T` as `Row`,
a component type that is itself structured. `Total(sub)` is indexed from 0 and
its three components are read, AP 6.7.3.9.4 indexing a slice from 1 whatever
the array's own bounds are.

`tests/dialect/generic_infer_errors.pas` gains `Total(byChar)` over
`array ['a'..'c'] of integer`, whose golden is the index message and **one
line, not two** — no `unknown function 'total'` follows it, which is how that
file records that the activation was well formed and the routine was produced.

A client probe put every array-ish actual through a generic slice formal: a
whole array, a slice of one, a packed char array, a schema-produced array, an
array indexed from 0, an array of arrays, and a row of one. All seven compile
and run; the variable-string is refused, in the same words the non-generic
form refuses it.

| Mutation | Killed by |
| --- | --- |
| `0316-inference-asks-for-a-slice` — the arm back to `IsSlice(t)` | `generic_infer` and `generic_infer_errors`, and **differently**: the first loses an activation that should compile, the second loses a diagnostic that should name the array |

## What is not done

**Nothing else that admits an actual by shape was swept.** This defect was one
predicate asked in one arm, and the reason it survived is that inference and
the actual-parameter check ask the same question in two places. They are still
two places: `CheckActualParams` reports and `Determine` binds, and a third
rule about slice actuals would have to be written twice again. Making them one
routine is a change with no defect behind it today, so it is not made.

**`generic_infer.out` and `generic_infer_errors.err` both move**, and the
argument for regenerating them is that the case is being asked new questions:
one golden gains two lines of new activations, the other's line numbers shift
by a declaration and it gains the message the fix produces. No existing line
of either changed its answer.

## Consequences

**A slice parameter is now what it was meant to be for a generic.** ADR-0266's
own example — `procedure Sort(Elem: ordered type; var a: array of Elem)` — can
be activated by inference from an array, which is the only way anyone would
write the call. Nothing in this tree was calling it that way, because nothing
could.

**AP 6.7.3.10.4 c) no longer defers to 6.7.3.9.3 for what it reads.** It
defers for what is *admitted*, which is where the refusal belongs, and decides
for itself what has a component type. That is a small divergence between two
clauses about the same parameter, and NOTE 8 exists so it reads as a decision
rather than as an oversight.

**The specification was right and the compiler was wrong, which is the way
round this project has been arranged for.** `doc/afterschool-pascal-spec.md`
is derived from the decision records and verified by probe, never from
`selfhost/compiler.pas` (ADR-0135), and here that independence is what made
the defect legible: the clause and the code disagreed, and the clause was the
one to believe. **Annex E takes no entry**, there being no divergence to
record — the document already said the thing the compiler did not do. A
specification written from the implementation could not have produced that
reading, and would have said `IsSlice`.
