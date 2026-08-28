# ADR-0153: Conformant array parameters, and level 1

Date: 2026-08-21

## Status

Accepted, and its *claim* withdrawn by
[ADR-0232](0232-afterschool-pascal-is-the-language.md). The conformant array
parameters are still accepted, exactly as described here; what is gone is the
level-1 compliance statement they were the whole of the difference for,
`doc/implementation-defined.md` 1 having been withdrawn rather than reworded.

## Context

ISO 7185 clause 5.1 a) defines **level 0** as clause 6 without §6.6.3.6 e),
§6.6.3.7 and §6.6.3.8. Accepting those three makes a **level 1** processor, and
this one declared level 0 — a complying level rather than a gap, but the only
one of the two that a document had to explain.

A **conformant array parameter** is a formal parameter whose bounds travel with
the actual:

```pascal
function total(var a: array [u..v: integer] of integer): integer;
```

One compiled body serves every extent an array-type can have, `u` and `v`
denote the smallest and largest values of the index-type the *actual* possesses
(§6.6.3.7.1), and §6.6.3.8's conformability is what decides which actuals fit.

**ADR-0152 is why this record exists now rather than later.** `doc/roadmap.md`
§2 said the dialect has no external authority for anything but the foreign
boundary; that survey found otherwise, and the counter-example was this clause —
§6.6.3.7 is a formal parameter whose bounds travel with the actual, which is
what AP §6.7.3.9's slice exists for and what ISO/IEC 10206:1991's schematic
formal (ADR-0040) already is. The roadmap had two entries about one clause and
had not noticed.

## Decision

**Implement all three clauses, and declare level 1.**

### The parser writes §6.6.3.7's full form always

```
unpacked-conformant-array-schema =
  'array' '[' index-type-specification (';' index-type-specification)* ']'
  'of' (type-identifier | conformant-array-schema)
```

§6.6.3.7 makes the abbreviated form — a single semicolon replacing the sequence
`] of array [` — equivalent to the nested full form, so `ParseConfArraySchema`
normalises to **one index-type-specification per node** and nothing after the
parser has two shapes to know about. It is the move `ParseArrayType` already
makes for §6.4.3.2's several indices, one clause later and for a construct that
nests rather than repeats.

`array [` is told from ADR-0125's slice (`array of`) by one token of lookahead
and from an ordinary parameter by two. Neither standard admits `array` in a
formal parameter's type position at level 0, so the spelling costs the grammar
nothing.

### The type is ADR-0040's descriptor, unchanged

This is the whole reason the feature is small. §6.6.3.7 asks for bounds that
travel with the actual; ADR-0040 built bounds that travel with the actual, for
ISO/IEC 10206:1991's schematic formal, five records ago.

- each bound-identifier is an **`skDisc`** reading the parameter's descriptor —
  and §6.6.3.7's NOTE 2 says the object one denotes "is neither a constant nor a
  variable", which `skDisc` already was, so the clause needed no kind of its
  own. Not assignable, not a `var` actual, and both refusals came for free;
- the index-type is a **subrange** whose ends are those two symbols, which is
  what `ResolveSubrange` already produces for `array [1..n]` inside a schema;
- ADR-0113's `BoundSchemaFor` gives the parameter the anonymous schema every
  descriptor-carrying symbol needs.

Indexing, the bounds check, whole-variable copying and the size walk are the
code that was already there.

**One type for the whole section.** §6.6.3.7.1 says "the formal-parameters shall
possess an array-type" — one for the parameters of one specification, not one
apiece — and the clause before it makes that sound, every actual of one
specification possessing the same type. It is also what a program can see:
`x := y` between two names of one section is conforming, and ADR-0017's name
equivalence would refuse it otherwise.

### Conformability and congruity are their clauses, statement by statement

`Conformable` is §6.6.3.8 a) to d); `EquivalentConf` is §6.6.3.6 e) 2) to 4).
Statement e) 1) — a single index-type-specification in each schema — is
satisfied by construction and has nothing to test, which is what normalising to
the full form buys.

### `src/` carries it

Level 1 is the conformance surface, so the reference front end implements the
parser and the whole of Sema (ADR-0108). `difftest` compares both over every
source in the tree and they agree.

## Consequences

**`doc/implementation-defined.md` §1 states level 1.**

### The BSI suite is a third-party corpus for exactly this feature

`tests/bsi/suite/LEVEL1/` is **51 programs** written in 1982 by people who were
not this project, and `expected.tsv` recorded all 51 as `REJECTED`. They now
behave as their own class headers require:

| Class | Programs | Verdict |
| --- | --- | --- |
| CONFORMANCE | 16 | all PASS |
| DEVIANCE | 26 | all rejected |
| ERRORHANDLING | 6 | compile and run |
| IMPDEF | 3 | compile and run |

**It found nine defects that the first implementation had**, and every one is a
program no corpus here contains:

1. a subrange as the ordinal-type-identifier built a subrange **hosting a
   subrange** — an invariant `Base()` relies on, being one level (LEV1F10);
2. two names of one section had two types, so `x := y` between them was refused
   (LEV1F10);
3. the value form demanded a variable-access, where §6.6.3.7.2 asks for an
   *expression* (LEV1F24, LEV1F41, LEV1F45);
4. §6.6.3.8 b) was checked at compile time against a T1 whose bounds are not
   known then, refusing a conformant array handed on (LEV1F44, LEV1F48,
   LEV1F49);
5. §6.6.3.7.1's "all possess the same type" was unchecked (LEV1F17, LEV1F19,
   LEV1F22);
6. a parenthesised actual was accepted for the variable form (LEV1F35);
7. §6.6.3.6 e) 2) compared the flattened index host, so `one = 1..10` and
   `two = 1..10` looked equivalent (LEV1F03);
8. a bound narrower than the descriptor's word was not truncated, and LLVM
   refused the module (LEV1F28);
9. a **row** of a two-dimensional conformant array passed as a one-dimensional
   one got bounds of zero, because the first draft walked the designator rather
   than reading the type's own `loDisc`/`hiDisc` (LEV1F45).

### And it found one this feature did not introduce

`pack` and `unpack` read the unpacked array's bounds from the *static* `lo` and
`hi`, and the packed array's span the same way. For any array whose extent
arrives with an actual those are placeholders, so **`pack` of a schematic
formal was already wrong** — ADR-0040's gap, and no program in the corpus packs
one. `EmitTransfer` now reads both through `BoundValue` and computes the length
and the offset dynamically, exactly as the subscript path does. LEV1F06,
LEV1F07 and LEV1F51 are the three programs; `tests/conformant.pas` packs and
unpacks through a schema so the corpus has one too.

The same shape reached the assignment: a **row** of a two-dimensional
conformant array has bounds in the descriptor and no schema of its own, so the
whole-variable copy took the static path and moved one component of however
many there are.

### What it does not do

**§6.6.3.8's closing error is not detected.** "It shall be an error if the
smallest or largest value specified by the index-type of T1 lies outside the
closed interval specified by T2" — and where T1 is itself a conformant array
schema, T1's bounds arrive with its own actual, so the comparison is a run-time
one this compiler does not emit. It is an *error* in §3.1's sense, which a
processor may leave undetected; `doc/implementation-defined.md` lists it with
the rest of Annex D, and BSI's LEV1F44 and LEV1F49 report `ERROR NOT DETECTED`
accordingly. Detecting it is a check at the call site against a constant
interval and is worth doing; it is not worth doing in the change that adds the
feature, because the check has no test that fails without it until the feature
exists.

**No `verify/` rule.** §6.6.3.7 adds no arithmetic lowering: the bounds check is
the array bounds check with its operands read from a descriptor instead of
written as constants, and `accepted-index-selects-the-right-element` already
quantifies over the bounds symbolically — which is what makes it say something
about this feature without being changed for it. ADR-0013's rule against a rule
that restates the lowering applies.

### Rejected: refusing `pack` and `unpack` over a dynamic extent

It would have left three conforming level-1 programs rejected, and a level-1
processor that rejects a conforming level-1 program is not one. The defect was
also older than this feature and had nothing to do with it.
