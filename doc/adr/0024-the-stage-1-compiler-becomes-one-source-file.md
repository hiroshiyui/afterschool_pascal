# 24. The stage-1 compiler becomes one source file, and Sema is checked on the tree it annotates

Date: 2026-08-10

## Status

Accepted. **The one-source-file half is superseded by ADR-0233**, which split
the compiler into three §6.13 program-components; the reason given below --
neither standard had an include mechanism -- expired at ADR-0053 and ADR-0079
and had been an unpaid debt since. Everything else in this record stands, the
half about checking Sema on the tree it annotates most of all: that contract
(ADR-0008) is what makes ApFront's interface small enough to be worth having.

## Context

The third component of the stage-1 compiler, and the largest: `src/sema.cpp`
and `src/type.h` are 1875 lines, more than the lexer and the parser together.

Two questions had to be answered before any of it could be written. The first
is structural. `selfhost/parser.pas` already carried its own copy of the lexer,
adapted to fill a table instead of emitting; a third program would have carried
*two* copies of everything below it, and by CodeGen that is three copies of the
lexer and two of the parser, each free to drift.

The second is what to compare. Sema produces no output of its own. What it
leaves behind is an annotated tree — ADR-0008's promise that codegen never has
to ask a question about the source program — and that annotation is the thing
worth checking.

## Decision

**The stage-1 compiler is one source file.** `selfhost/compiler.pas` is the
lexer, the parser, the AST and Sema; `lexer.pas` and `parser.pas` are gone into
it. ISO 7185 has no include mechanism, so this is where the port was always
going — the earlier files each said "written to be pasted into one source", and
this is the paste. Each later component is merged in the same way.

What the merge costs is the ability to run one stage alone, so **the program
dumps every stage in one pass** — `=== tokens`, `=== ast`, `=== sema` — and
`pascalc --dump-all` does the same. There is no mode argument on the Pascal
side because there is no second binary to select. `difftest.sh` lost its mode
argument with them, and `selfhost-lexer` and `selfhost-parser` became
`selfhost-compiler`.

**Sema is compared on the tree it annotates.** `--dump-sema` walks the same
tree as `--dump-ast`, through the same walker with an `annotate` flag, and adds
what Sema alone knows:

- the **activation record of every block** — each slot, its kind, its number
  and its type, in the order ADR-0016 lays them out. A name that resolves to
  the right symbol but the wrong slot is a bug that only this catches;
- the **type of every expression**, and for a name **which frame slot** it
  resolved to, rather than its spelling again;
- the **layout of every record type**: each field's index and variant, the tag
  field, and the folded tag values of each arm;
- the **file** a read or a write acts on, which Sema moves out of the argument
  list or supplies — after it the tree has a shape the parser never built;
- the **folded values** of every case label.

Sharing one walker between the two dumps is deliberate: the shape is then the
same question asked twice, once before annotation and once after, and a change
to one cannot silently diverge from the other.

## Consequences

The port has a third working component. 173 files agree stage for stage at
`-O0` through `-O3`, the compiler's own 5900 lines included, and the corpus is
clean under ASan and UBSan.

**Two stage-0 changes were made for the port, both of which stand on their own.**

`Sema::checkWith` named its hidden binding `with$` plus the record's type name.
Reproducing that would have needed a whole second, *string-building* copy of
`Type::name()` in Pascal — the one string-valued function ADR-0012 measured as
avoidable, for a spelling that reaches nothing but an IR label. It is now
`with$` plus the frame slot, which is unique within the frame and needs no type
name at all.

`Type::ordinalName` wrote a char constant literally. A diagnostic is printed
with `%s`, so a char of value 0 **truncated the message at that point** —
`array [` and nothing more. It now writes `chr(n)` for anything unprintable.
That bug had been there since ADR-0018 and was found by a corpus file written
to close a mutation gap, not by reading.

**Four more things the language decided rather than we did.**

- **A selector may follow only a variable-access** (ISO 7185 §6.5.1), so
  `Base(t)^.kind` — which the C++ writes throughout `type.h` — cannot be said
  at all. Every predicate takes a local first. This is the same restriction
  that made `f(x)^` illegal for the parser, met from the other side.
- **The C++ computes the array-span check in a 64-bit type.** `hi - lo` for the
  full integer type is `2*maxint`, which is not a value of the Pascal integer,
  so the test was rearranged to stay inside the type: with `lo` above zero the
  span cannot reach `maxint` at all, and otherwise `maxint + lo` is in range
  and `hi - lo >= maxint` exactly when `hi >= maxint + lo`. This is the second
  time a check had to be rewritten because this compiler traps where C wraps
  (ADR-0022 was the first), and it is now a pattern rather than an incident.
- **`||` short-circuits.** `resolveSubrange` evaluates its upper bound only if
  the lower one was a constant, and `evalOrdinal` type-checks as a side effect,
  so a port that evaluated both would report a different number of errors on
  the same file. Written out as nested `if`s here, with a note saying why.
- **An empty statement before `else` is legal ISO Pascal and this compiler
  rejects it.** Found where the C++ writes `continue`; the condition was folded
  into the following test instead. Recorded in the roadmap as a limitation of
  stage 0 rather than worked around silently.

**The error corpus grew again, and again because of a measurement.** Before
`selfhost/badsema/`, the corpus reached 48 of Sema's messages; it now reaches
83. Sema does not stop at its first error the way the parser does, so unlike
`badparse/` one file can carry many, and eight files cover the surface.

**The test is known to be able to fail.** Nine mutations were applied to the
Pascal Sema: making two enumerated types compatible, numbering frame slots from
one, ending `char` at 127, dropping `packed` from the string-type test,
numbering enumeration constants from one, moving the array-span bound by one,
stopping `Base` from looking through a subrange, defaulting `write` to `input`,
and emptying the `with` stack. Six were caught immediately.

The three that escaped are the useful part. Two were closed by
`badsema/edges.pas` — nothing in the corpus had an *unpacked* array of char, or
an index spanning exactly `maxint`. The third needed more: `char`'s last value
is observable only through an array indexed by `char` whose type is
**anonymous**, because a named one prints its alias instead of its bounds. The
file written to expose that is what found the truncation bug above.

**What is still not converted.** A real literal is still carried as text, and a
real *constant* in the Pascal Sema carries no value at all — nothing in Sema
reads one, so keeping it would have meant implementing the conversion to hold
something unused. `--dump-sema` prints `const real` for that reason, the same
reason ADR-0022 gives for the token dump. This is the third record to defer it;
CodeGen is where it stops being deferrable, because a value must be emitted.

The fixed tables grew with the source they have to hold: 90000 tokens and
400000 characters of text. Both are frame storage, both are the limits
ADR-0012 predicted, and both fail loudly.
