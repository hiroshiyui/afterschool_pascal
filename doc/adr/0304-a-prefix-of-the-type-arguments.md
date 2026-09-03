# 304. A prefix of the type arguments

Date: 2026-09-03

## Status

Accepted, 2026-09-03. Closes `doc/roadmap.md`'s "Writing a daily program"
entry *the library has not caught up with the language's inference, measured
again* (ADR-0295 finding 2), and widens AP 6.7.3.10.4 as
[ADR-0254](0254-a-generic-activation-need-not-write-its-types.md) first wrote
it.

## Context

The roadmap's row read:

> `MapGet(CountMap, integer, counts, w, 0, StrHash, StrEq)` is seven arguments
> for a lookup, two of them types the call already knows, **because a type
> appearing only in the result must be written and ADR-0254's rule is then all
> or nothing**. `MapPut` beside it writes none.

**The clause after "because" was false, and the probe is what said so.** The
first program written for this record was `MapGet(counts, w, 0, StrHash,
StrEq)` against the library as it stood, and it compiled and printed 3. Nothing
had ever tried it. `MapGet`'s element type does not stand only in the result:
`whenAbsent: Elem` is a value parameter, AP 6.7.3.10.4 a) reads it, and the
call has been inferable since the day inference landed.
`lib/dialect/pascontainer.pas`'s own header comment asserted the opposite —
*the two that must still be written are `MapGet`'s and `MapKeyAt`'s element
types* — and `examples/word_freq.pas` was written from the comment rather than
from the compiler. This is ADR-0297's four-day gap met a second time in the
same module: the entry that asked for a feature went on describing the tree
from before it.

A sweep of the whole container interface put the real boundary where nobody had
looked. `MapInit`, `MapFree`, `MapPut`, `MapCount`, `MapSlots`, `MapLiveAt`,
`VecInit`, `VecFree`, `VecPush`, `VecPop`, `VecSet`, `VecLen`, `VecCap`,
`VecFull`, `VecClear`, `VecReserve` and `MapGet` all infer today and write
nothing. **Two routines do not, and both for the same reason**: `VecGet`'s
`Elem` and `MapKeyAt`'s `K` stand only in the result type, and §6.7.1 makes a
result-type a type-name and not an actual, so no argument can say what they
are.

That is where the row's other clause was right. ADR-0254 admitted two forms and
only two — every type argument written, or none — so a routine with one
undeterminable type parameter made the caller write the determinable ones too.
`VecGet(PathVec, PathName, files, i)` in `lsp/pasls.pas` names `PathVec` where
`files` is a `PathVec`, eight times.

## Decision

**An activation may write a prefix of its type arguments and leave the rest to
be inferred.** AP 6.7.3.10.4 is amended; the two forms ADR-0254 admitted are
the ends of the range, *k* = *n* and *k* = 0.

**Why a prefix.** The written type arguments have to be identifiable, and there
are three ways to do it: read the list to find where the types stop, name the
ones written, or fix them by position. A prefix fixes them by position and
costs nothing to decide — *k* is *a* − (*m* − *n*) from the arity alone, so the
arity says how many types were written before any actual is looked at, exactly
as ADR-0254's two counts did. The alternative that was weighed and dropped is
"the written arguments fill the type parameters *no actual can determine*",
which needs no ordering of the declaration but makes a reader work out which
those are before they can read the call; the prefix moves that decision to the
declaration, where it is written once. So a generic declares its undeterminable
type parameters first, and `VecGet` and `MapKeyAt` now do.

**ADR-0254's reason still stands and this does not touch it.** All-or-nothing
was never argued for on its own; what ADR-0254 argued is the tie-break — *an
actual that denotes a type cannot denote a value* — and it is the same sentence
here, asked at the position of the first **omitted** type parameter rather than
the first type parameter. `generic_errors.pas`'s `P(integer)` against
`procedure P(T: type; var a: T)` is the case it was written for and still says
what it said.

**Three walks became three passes and one of them merged.** In
`InstantiateGeneric`: the written type arguments are read and bound first, so a
written one is the first determining position and no actual redetermines it;
the actuals then determine what is left; and the tuple is built from one walk
over the bindings, where before there were two disjoint walks for the two
forms. The husk removal no longer steps over an actual for a type parameter
that has none.

## Evidence

**The probe is the case.** `tests/dialect/generic_infer_partial.pas` pins
*k* = 1 of 2 and *k* = 1 of 3; a type parameter standing *after* a value
parameter, so that the tie-break's position is the third formal and not the
first; the partial and the written form of one activation printing `TRUE` for
being one instantiation; and `Held(real, 2, 65)`, where a written `real` is not
redetermined by an integer actual that could have determined it — the `:6:2`
would not compile if it were. `generic_infer_errors.pas` gains `Pair(integer,
3)`, a written prefix that leaves a type parameter determined by nothing, and
the refusal names which one:

    nothing in this call says what 'u' of 'pair' is: write the type
    arguments, or pass an argument whose type determines it

Three scenarios were added to `tests/spec/features/dialect_typeparam.feature`,
which is 20 of 20.

**Two mutations, in `tests/mutation/mutants/`.**
`0304-tie-break-asks-the-first-type-parameter` restores ADR-0254's position for
the question and fails `generic_infer_partial`: every partial activation then
finds a type standing where it looks and is read as a written one short of an
argument. `0304-omitted-type-parameter-eats-an-actual` restores the lockstep
husk removal, which deletes the value actual that follows an omitted type
parameter, and fails the same case.

**The measurement.** `examples/word_freq.pas`, which is the row's own
instrument, before:

```pascal
  MapInit(CountMap, counts, 64);
  n := MapGet(CountMap, integer, counts, w, 0, StrHash, StrEq);
  writeln(MapGet(CountMap, integer, counts, SVecGet(words, k), 0,
                 StrHash, StrEq):4, ' ', SVecGet(words, k));
  writeln(MapCount(CountMap, counts):1, ' distinct words');
  MapFree(CountMap, counts)
```

after:

```pascal
  MapInit(counts, 64);
  n := MapGet(counts, w, 0, StrHash, StrEq);
  writeln(MapGet(counts, SVecGet(words, k), 0, StrHash, StrEq):4,
          ' ', SVecGet(words, k));
  writeln(MapCount(counts):1, ' distinct words');
  MapFree(counts)
```

The example names one type, `CountMap`, and it is in the type-definition where
a reader wants it. **None of those five lines needed the language change** —
all five are ADR-0254's feature, unused for four days because a comment said it
was unavailable. What needed it is the other fifteen: `VecGet` loses a type
argument at fourteen call sites and `MapKeyAt` at one, eight of them in
`lsp/pasls.pas`, and `lib/dialect/pasjson.pas`'s `VecGet(JsonChars, char, b,
i)` is `VecGet(char, b, i)`.

**Gates.** 828 of 828 ctest cases, the new one among them; `irtest.sh` reports
stage 2 = stage 3 over all three components; `producttest.sh` 25 of 25.
`unicode-conformance` skipped for want of the database, as it does here.

## What is not done

**Nothing was reordered but the two routines that had to be.** `VecGet` is
`(Elem, Ptr, …)` and `MapKeyAt` is `(K, Ptr, …)`, which is a **breaking
change** to two exported signatures: a client writing `VecGet(IntVec, integer,
v, i)` now names the pointer type where the element type is expected and is
refused. Every call site in this tree moved with it, and nothing outside the
tree exists.

**The result type is still a type-name.** What would remove the last written
type argument outright is `function VecGet(…): type of v^.a[1]`, which §6.7.1
refuses; `doc/history.md` and ADR-0215 carry that reading and it is unchanged.
This record makes the written argument cheap rather than unnecessary.

**No category is inferred.** AP 6.7.3.10.5's constraints are checked against
whatever the tuple ends up holding, written or determined, and `ReportCat`
names the determining actual only for an argument nobody wrote. That is
ADR-0266 unchanged.

## Consequences

- **A type argument dropped by mistake is not always refused.** With two forms,
  any list of the wrong length was an error; with a range of them, a list one
  shorter than intended can be a well-formed activation of a routine the writer
  did not mean, provided every remaining type parameter is determined and every
  actual fits the formal it then matches. AP 6.7.3.10.4 NOTE 6 says so. This is
  the price of the feature, and it is the same price inference itself charges —
  ADR-0254 accepted that a call may choose a type nobody wrote — but the range
  makes the surface wider, and it is why the tie-break is kept rather than
  replaced by arity alone.
- **A signature now carries an ordering decision.** Which type parameters an
  activation must name is fixed where the generic is declared, by putting the
  undeterminable ones first. That is a property a reader can check against the
  result type in one glance, and `lib/dialect/pascontainer.pas` says so at both
  headings — but it is a convention, and nothing in this tree enforces it: a
  generic that declares them the other way round simply cannot be called
  partially.
- **A library header comment is an oracle nothing reads.** Two of them were
  wrong in this one module — *the two that must still be written*, and a "why
  two type arguments and not one" paragraph describing a call shape three
  features had superseded — and both survived every gate here, because a
  comment compiles. ADR-0295's whole finding was that reading the corpus is
  what catches this, and it caught it twice in one file.
