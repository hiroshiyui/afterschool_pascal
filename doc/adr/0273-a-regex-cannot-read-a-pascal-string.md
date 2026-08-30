# 273. A regex cannot read a Pascal string, and the diagnostic gate was one

Date: 2026-08-31

## Status

Accepted, 2026-08-31.

## Context

`diagnostic-coverage` is the gate that says every message this compiler can
write is named by some golden. It found the message it was looking for with

    write(?:ln)?\('([^']{20,})'

which requires the first character after the opening quote to be an ordinary
one. §6.1.7 writes an apostrophe inside a string-literal as **two**, and this
compiler's commonest diagnostic shape puts the offending name first and starts
the message mid-sentence:

    write('''');
    WritePool(sym^.at, sym^.len);
    writeln(''' is already declared in this block')

The literal there begins with a doubled quote, so the pattern matched nothing
at that site, and `re.finditer` found no other `write('` on the line to try.
The message was invisible.

**255 of 724 were.** The gate reported the set as fully covered by never asking
about a third of it.

It surfaced because ADR-0272's first warning is exactly that shape. It was
written, it fired, `tests/unused_local.warn` named it — and the gate said
nothing either way, which is how a check that cannot see its subject looks from
outside.

## Decision

The literal is **scanned**, not matched: from the opening quote to the first
quote that is not doubled, with each doubled pair yielding one apostrophe. That
is also what the goldens hold, so what is compared is the text a reader sees.

A newline ends the scan and discards the candidate. §6.1.7 puts no newline in a
literal, so reaching one means the opening quote was not one — and without that
a mismatched quote would swallow the rest of the file.

The regex that remains finds only where a literal *begins*. What it contains is
not a regex's question, and this record exists because reading it as one held
for as long as the gate has.

## Consequences

**26 diagnostics no golden named**, found at once. 23 are reachable and have
cases here — six in `selfhost/badparse/`, one per message because the parser
stops at its first error, and five files in `selfhost/badsema/`, which
accumulates:

| case | what it covers |
| --- | --- |
| `badparse/restricted-name`, `typeof-name`, `conformant-upper` | §6.4.2.5, AP 6.4.9 and §6.6.3.7.1 each naming an identifier and getting something else |
| `badparse/module-implementation-semi`, `module-heading-end`, `module-block-end` | §6.11.1's and §6.13's three separators, none of which any case had written wrongly |
| `badsema/schemadomains` | the three positions that ask a schema for a type and say which position they are, plus §6.4.2.5's `restricted` naming a variable |
| `badsema/channels` | AP 6.4.16 and 6.9.3.13 — both arities, both designator rules, and a capacity that is not constant |
| `badsema/requiredargs` | `binding`, `index`, `substr`, `cmplx` and §6.8.7.2's array-value selector |
| `badsema/qualname` | §6.11.3's qualifier that is not an interface, and a qualified function written without its arguments |
| `badsema/twoimplementations` | §6.11.1's one implementation per module, two of them in one component |

**Three are unreachable and are argued, not exempted.** Each has the argument
at its own site as well as in `unreachable_diagnostics.txt`, which is that
file's own rule:

- `' cannot be imported'` — a constituent is made in two places and neither
  leaves `sym` nil by the time it is asked: the export-part adds one only after
  finding a symbol, and the two required interfaces' constituents are filled by
  `EnsureStdFile` in the import loop above the call.
- `' has no discriminants'` — `CheckTypeDecl` calls `DeclareSchema` only when a
  formal-discriminant-part was written, and every group in one appends a symbol
  per name; an empty list needs a group with no names, which the parser cannot
  build without reporting, and Sema does not run after a parse error.
- `' is not a function with a result'` — `named` is set only for an `skFunc`
  and `InstantiateHeading` gives every one a result variable; the single symbol
  that skips it is a generic's own, and §6.8.2.2's containment walk has already
  remapped that to the instantiation or reported that the name is not this
  block's function.

**Two of the six parser cases needed a second look at what a name may be.** The
first spelling of `badsema/qualname` was called `qualified`, which §6.1.2
reserves — *expected the program name* at column 9, in a file about qualified
names. ADR-0232's cost, met in passing.

**What this does not close.** An entry in `unreachable_diagnostics.txt` naming
a message that does not exist is still ignored rather than reported: the gate
computes *unnamed* and *revived* and neither sees an entry matching nothing. It
would have caught the three entries this record added in the wrong spelling —
they were written without the leading apostrophe, the old matcher's shape — and
instead they were caught by the three messages staying unnamed, which is the
same fact arriving the long way round. `doc/sop.md` §7 has it.
