# ADR-0150: A file inside a record is still a file

Date: 2026-08-21

## Status

Accepted. A conformance defect in both standards' modes, found by ADR-0149's
survey and confirmed by BSI's DEV102, which had been recorded as a wrong answer
for as long as the catalogue has existed.

## Context

ISO 7185 §6.4.6 a) is **two conditions**:

> T1 and T2 are the same type, **and that type is permissible as the
> component-type of a file-type** (see 6.4.3.5).

§6.4.3.5 defines that second condition: a type-denoter is not permissible when
it denotes a file-type, or a structured-type having any component whose
type-denoter is not permissible. A file at any depth, in other words —
`ContainsFile`, which this compiler already had and already asked in four
places: the component-type of a file (§6.4.3.5 itself), a value parameter
(§6.6.3.1), a function result (§6.7.2) and a structured value (§6.8.7.1).

ISO/IEC 10206:1991 §6.4.6 a) is the same sentence against its own §6.4.3.6, so
it is one rule under both standards.

`Assignable` read only the first condition:

```pascal
else if IsFile(toT) or IsFile(fromT) then
  Assignable := false
```

So a bare file was refused and a record holding one was not:

```pascal
type r = record f: text; n: integer end;
var a, b: r;
begin rewrite(a.f); rewrite(b.f); b := a end.
```

**Accepted, under all three modes.** A structured assignment is a memcpy
(ADR-0017), and what it copies here is the file variable's own storage — so
`a.f` and `b.f` then name one `struct pas_file`, and closing the block closes
it twice:

```
free(): double free detected in tcache 2
```

SIGABRT, exit 134, from a program §5.1 e) requires a processor to reject before
running anything at all.

**BSI's DEV102 is this program.** Its header reads *TEST 6.4.6-6, CLASS=DEVIANCE*
and *Structured-types containing a file component should not be assigned to each
other*. `tests/bsi/expected.tsv` recorded it `TRAPPED` — the **one** DEVIANCE
program of 266 this compiler did not reject. The catalogue was right about what
the compiler did and nobody read the column; the row had been sitting there
since ADR-0086, in a file whose header says a difference fails in either
direction.

## Decision

**Ask `ContainsFile`, which is what the clause asks.**

```pascal
else if ContainsFile(toT) or ContainsFile(fromT) then
  Assignable := false
```

`ContainsFile` answers true for a bare file as well, so this is one predicate
where there were two and `IsFile` is no longer asked at this site. The arm keeps
its position at the head of `Assignable`, where the unconditional refusals live.

**And a message of its own**, beside the slice arm ADR-0143 added for the same
reason: rendered through the general message this reads *cannot assign r to a
variable of type r*, which is accurate and says nothing about the file inside r.
The words are the ones a value parameter of such a type is already refused with
— *it contains a file, and a file has no copy* — because it is one fact. It is
asked **inside** the failure and not ahead of it, which is ADR-0143's own
finding: a guard placed before the predicate masks it at the only site that
reaches it, and the predicate stops being the thing under test.

**`src/` carries it too.** This is the conformance surface, so the reference
front end must give the same answer or `difftest` reports a disagreement on
every program that assigns a file-bearing structure — and it did report one, on
`tests/extended/structvalue_errors.pas`, before `src/sema.cpp` was changed to
match.

## Consequences

`structvalue_errors.err` gains one line. Its line 73 constructs a structured
value of a file-bearing type and assigns it, so §6.8.7.1 reports the value and
§6.4.6 a) now reports the assignment — a second message about one line, in the
shape that golden already has twice at lines 70/71 and 75/75. Both front ends
write it, so difftest agrees.

`tests/bsi/expected.tsv`'s DEV102 moves from `TRAPPED` to `REJECTED`, and all
266 DEVIANCE programs are now rejected.

Two mutations:

- **`ContainsFile` back to `IsFile`.** Six cases fail:
  `file_in_record_assign`, `structvalue_errors`, `bsi-validation-suite`
  (DEV102), `difftest` (the two front ends now disagree), `line-coverage`, and
  `predicate-callers` — the last because the gate reads the arm's predicate
  from the source and finds a wrapper with nothing to answer for.
- **The bespoke message disabled**, the predicate left alone. Five fail, and
  `bsi-validation-suite` is *not* among them: the program is still rejected, so
  the fix is real and the wording is separately load-bearing.

`predicate-callers` was extended rather than left alone (ADR-0146). Its
`REFUSES` pattern was keyed on an `Is` prefix, which would have read this
rename as the arm going away; it now matches a refusal arm by whatever its
predicate is called. And `WRAPPERS` maps a predicate to a **list** of
spellings, because `ContainsFile` refuses a bare file and a record holding one
and those are two different programs at each of the 21 positions: 84 pairs
where there were 63, and every one refused.

### What it does not change

**Nothing about how a file is passed or stored.** `isStructured()` still
excludes a file, `isMemory()` still means "travels by address", and a
file-bearing record is still a legal type, a legal `var` parameter and a legal
field. What it may not be is the subject or the object of an assignment, which
is the one operation §6.4.6 a) governs.

**The relational operators needed nothing.** They ask `Assignable` too — which
is ADR-0058's sentence, and here it works in the useful direction — but neither
standard gives a record or an array of files a relational operator anyway, so
the arm changes no program there.

### Why no oracle here had said so

Worth recording, because five of them looked at it:

- **the goldens** agreed with the compiler, having been written by it;
- **difftest** compared two front ends that shared the misreading, which is
  exactly the failure mode ADR-0072 named — one author, one reading;
- **`verify/`** models the lowering and this is a type rule;
- **`predicate-callers`** derived its type list from `Assignable`'s own arms, so
  it swept the types the defect had already excluded;
- **the BSI suite** *did* say so, in a row nobody read.

The one that worked was a survey with a clause in front of it, which is
`langspec-audit`'s method arrived at from the other direction: ADR-0149 was
examining what an optional's component may be, wrote `?record a: text end` to
see it refused, and it was not.
