# ADR-0124: Every case over a type kind names every kind, and a gate says so

## Status

Accepted. The seventh catalogue, and the first gate here written because a
defect had already shipped twice rather than because a feature needed one.

## Context

A Pascal case-statement stops the program when no label matches (ADR-0018).
`selfhost/compiler.pas` switches on `typeKind` in six places — `WriteTypeName`,
`StaticThroughout`, `LlAlign`, `LlSize`, `PutLlType` and the constant-operand
emitter — and each writes out every kind. A kind left off one of them is
therefore a **compiler crash** on the first program that reaches it.

**No gate here could see that**, and the reason is worth stating precisely
rather than as "we had no check":

- `line-coverage` counts *statements*. A missing arm is not a statement, so
  there is nothing for it to report as unreached.
- `procedure-coverage` asks whether a procedure was *entered*. All six of these
  are entered by nearly every program in the corpus.
- No golden can hold it. A golden compares what the compiler wrote; a crash
  writes nothing, and the case that would have exposed it did not exist —
  which is the whole point, since if it had existed the crash would have been
  found.
- `difftest` cannot report it. `src/`'s counterparts are C++ `switch`
  statements with a `default`, so the reference front end *answers* where the
  Pascal crashes. There is no disagreement to compare, only one side falling
  over. The §7 register already named this: "the C++ has always been right
  here, and difftest could not report it because the Pascal crashed rather
  than disagreeing."

### It has happened twice

`StaticThroughout` listed fifteen of sixteen kinds and omitted `tyString`.
Every schema type containing a variable-string stopped the compiler for as long
as that took to find.

Then ADR-0123 added `tyOptional` as the seventeenth kind, swept four of the six
case-statements, and missed the same routine. The result was shipped: with 578
`ctest` cases, difftest, `irtest`, `producttest`, `verify/`, `llc`, the BSI
suite and every CI job green, this crashed the compiler —

```pascal
type Box(n: integer) = record slot: ?integer; pad: array [1..n] of integer end;
procedure show(var b: Box);          { a schematic formal parameter }
```

`doc/sop.md` §7 had carried a row naming this hazard, naming the routine it had
happened in, and ending: **"A mechanical check is cheap and is not written."**
It was right about all three.

That is the argument for writing it now rather than a fourth hand sweep. A
register entry that predicts a defect, and then the defect happens anyway, is a
register entry that has finished being useful as prose.

## Decision

`tests/checks/kind_exhaustive.py` reads `selfhost/compiler.pas`, takes the
`typeKind` enumeration as declared, finds every `case … kind of`, and requires
each to name every kind. It is a `ctest` case, so it runs before a push rather
than reporting after one.

### It fails in both directions

Which is `verify/`'s `KNOWN_GAP` rule (ADR-0013) applied to a seventh
catalogue:

- **a kind a case-statement does not name** — the crash is there, waiting for
  the first program that reaches that arm;
- **a kind named by no case-statement at all** — a kind nothing switches on is
  one that was removed from the type and left in the enumeration, or one added
  and never used. Either way the enumeration is describing a compiler that does
  not exist.

### What it reads, and why that is enough

Comments and string literals are blanked out first — keeping every newline, so
the line number it reports is the line a reader can go to — and then arms are
delimited by counting `begin`/`case`/`record` against `end`. That is sufficient
because this source has no other nesting construct, and it is *necessary*
because the file is 24,000 lines of prose containing the word "end".

A `case` naming fewer than four kinds is not one of these: it is switching on
something else that happens to be called a kind, of which this compiler has
several. Six is what it finds today and the count is reported, because an empty
result and a clean result must not look alike — the same reason `difftest`
checks how many files it compared.

### What it deliberately does not do

**It does not judge whether an arm is right.** `tyOptional: StaticThroughout
:= true` satisfies this check and is wrong — it would report a dynamically
bounded array inside an optional as statically sized, and let a schema through
to compute a field offset from a size nothing knows.

That is not a weakness to be apologised for; it is the division of labour. The
gate turns a *crash* into a *review*: it guarantees that every kind was
considered at every switch, and the answer given there is then an ordinary
claim, which ordinary evidence covers.
`tests/dialect/optional_dynamic.pas` is that evidence for the arm this record
was written about, and it exists because the mutation for it survived the gate.

## Consequences

- **Adding a type kind now costs six arms and the check says so**, naming each
  line. That is the cost being made visible rather than added: it was always
  six, and what was missing was anything that would tell you.
- **`doc/sop.md` §7 loses a row.** It is the first row retired by writing the
  thing it asked for rather than by a feature happening to close it.
- **The other enumerations are not covered.** `tokenKind`, `nodeKind` and the
  link kinds are switched on far more widely, and a `case` over a node kind
  that omits an arm is the same crash. This gate reads `typeKind` alone,
  because that is the enumeration both defects were in and because the node
  kinds are already caught in practice: the parser and both walkers enumerate
  them in lists the compiler itself rejects a duplicate in, which is how the
  two duplicate-label errors in ADR-0123 were found at build time. Extending
  it is cheap and is not done; §7 carries that.
- **It does not run on `src/`.** The reference front end's counterparts are
  `switch` statements with a `default`, which cannot crash — the hazard is
  specific to a language whose case-statement traps.

## Alternatives rejected

- **An `otherwise` on each case-statement.** ISO/IEC 10206:1991 §6.8.3.5 has
  one and the compiler is written in that language, so this was available. It
  converts a crash into a *silently wrong answer*, which is worse: the whole
  reason the `tyString` omission was found at all is that it stopped the
  compiler. A trap is a bad failure mode with a good property.
- **A fourth hand sweep.** Three had already been done, one of them in the
  change that introduced this defect.
- **Waiting for the eighth type kind.** The cost of the check is an afternoon;
  the cost of the last two omissions was a shipped compiler crash apiece.
