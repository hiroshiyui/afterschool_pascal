# 22. The lexer port is checked differentially, not by golden output

Date: 2026-08-10

## Status

Superseded by [ADR-0085](0085-stage-0-is-retired.md).

The decision here was "checked against the C++ lexer, **not** against a golden
file", and retiring stage 0 left no C++ lexer to check against. The lexer is now
pinned by goldens — including `selfhost/torture.pas`, which this record
introduced and which survived as a case of its own. What that trade costs is
argued in ADR-0085; the reasoning below is why it was worth not making for as
long as it could be avoided.

## Context

The first component of the stage-1 compiler. ADR-0004's dependency list is
finished — the language accepts everything the port needs — so this is the
beginning of the port itself rather than of another feature.

The roadmap already committed to the checkpoint: once both compilers exist they
should produce equivalent output for every file in `tests/`, and a disagreement
found there is bisectable, where the same disagreement found at stage 3 is two
binaries differing by a byte with nothing to compare but their output.

The question this record answers is how to make that concrete for a component
that produces no observable behaviour of its own.

## Decision

**The Pascal lexer is checked against the C++ lexer, not against a golden
file.** `pascalc --dump-tokens` and `selfhost/lexer.pas` write the same format,
and `selfhost/difftest.sh` diffs them over every `.pas` in the tree — 34 files,
about 15 700 tokens. It runs under `ctest` as `selfhost-lexer`.

A golden file would have been easier and would have tested the wrong thing: it
would pin the Pascal lexer to whatever it did on the day it was written. The
C++ lexer is the specification here, and comparing against it is what makes the
test say "these two agree" rather than "this one has not changed".

**The corpus includes the lexer's own source.** `selfhost/lexer.pas` is the
largest and most varied Pascal in the repository and the shape the rest of the
port will take, so lexing it is the most representative single case available.

**`selfhost/torture.pas` covers what the corpus cannot.** It is deliberately
not a valid program: unterminated comments and strings, unexpected characters,
literals past `maxint`, every form of exponent, `1..9` where the dot must not
start a fraction, embedded quotes, and whitespace that is not a blank. Real
test programs are valid by construction, so the error paths would otherwise
never be compared.

**Two passes, not a buffer.** Errors must all precede tokens so one stream
carries both, and the Pascal lexer gets that by scanning the file twice — once
reporting, once emitting — rather than holding either in memory. `reset` makes
the second pass one line, which is what ADR-0021's file model was for.

**A real literal is compared as its source text**, and an out-of-range integer
as `int ?` on both sides. Comparing converted doubles would compare two
languages' float formatting; comparing the value left behind by a rejected
literal would compare two accidents, since the C++ lexer converts in a wider
type and the Pascal one detects the overflow while accumulating.

## Consequences

The port has a working first component, and the checkpoint the roadmap called
for exists as a test rather than as an intention.

Three things the port revealed about writing this compiler in its own language,
recorded because the next three components will meet them again:

- **ISO's file model gives one character of lookahead; the lexer needs three.**
  An exponent is only an exponent if a digit follows the optional sign, so
  `1e+5` cannot be decided from `f^` alone. The Pascal lexer maintains a
  three-character window over the buffer variable. ADR-0021 kept `f^` because a
  lexer wants lookahead, and that was right — it is just not *enough* lookahead,
  which is worth knowing before the parser is ported.
- **The overflow check must precede the multiply.** The C++ lexer converts in a
  64-bit type and compares afterwards. That is not available in a language whose
  integers trap on overflow (ADR-0014), so the Pascal lexer tests
  `value > (maxint - digit) div 10` before accumulating. The compiler's own
  strictness changes how its source has to be written.
- **Pascal has no early return and no way to discard a function result.** The
  emit guard wraps a procedure body rather than leaving it early, and `Advance`
  is a procedure with a separate `Peek` rather than a function whose result is
  thrown away. Both are shapes the rest of the port will use.

**What is not covered.** The Pascal lexer does not convert a real literal to a
value — the comparison is on text, so an untested conversion would be worse
than an absent one. It arrives with the parser, which is the first thing that
needs the value. Identifiers and literals are capped at 255 characters, one of
the limits ADR-0012 predicted a fixed buffer would impose; exceeding it makes
the two lexers disagree, which is a visible failure rather than a silent one.

**The test is known to be able to fail.** Six deliberate mutations were applied
to the Pascal lexer and all six were caught: dropping the underscore from
identifiers, an off-by-one in the exponent lookahead, a double column advance,
no case folding, a dot always starting a fraction, and a tab no longer counting
as whitespace.

The last of those was **not** caught on first attempt, and that is the useful
part of the exercise: no file in the corpus contained a tab, so `IsSpace`'s
control-character branch was never exercised. The whitespace block in
`torture.pas` exists because a broken lexer went undetected, not because
somebody thought of it.

One mutation also revealed a weakness in the harness rather than in the lexer.
A scanner that recognises no character consumes none, so the mutant did not
produce a wrong token — it looped forever, and `difftest.sh` hung with it. The
Pascal lexer now runs under a timeout, and failing to terminate is reported as
the failure it is.

## Notes for the port

The program is written to be pasted into one file. ISO 7185 has no include
mechanism, so the finished compiler is a single source, and everything in
`selfhost/lexer.pas` below the character source is declarations the parser and
the rest will share. `program Lex(output, source)` and its `Scan` driver are the
only parts that will not survive the merge.
