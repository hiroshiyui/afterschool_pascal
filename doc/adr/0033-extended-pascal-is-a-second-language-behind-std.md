# 33. Extended Pascal is a second language, selected by `--std`

Date: 2026-08-10

## Status

Accepted.

## Context

ISO 7185 is complete (ADR-0032), and the roadmap has always named ISO/IEC
10206:1991 — Extended Pascal — as the second stage rather than an ad-hoc pile
of extensions. Starting it needs one decision made before any feature: what the
compiler *is* now.

The obvious answer, "a superset — just add the features", is wrong here, and
the repository proves it. Extended Pascal adds word-symbols: `otherwise`,
`value`, `only`, `module`, `export`, `import`, `pow`, `and_then`, and more. A
valid ISO 7185 program may use any of them as an ordinary identifier, and this
one does — `selfhost/compiler.pas` has a record field named `value`, and the
corpus has 148 further uses of these spellings as names. Reserving them
unconditionally would stop the stage-1 compiler compiling itself.

So the two standards are not nested. They are two languages, and a source is
written in one of them.

## Decision

**`--std=iso7185` (the default) or `--std=extended`.** The default is ISO 7185
because that is what the 207-file corpus, the SMT catalogue and the stage-1
compiler are written in, and because ADR-0012's escape hatch — stage 1 is a
Standard Pascal program, so any ISO 7185 compiler can build it — is worth
keeping. Extended Pascal is opted into, per source.

**The standard is a property of the source, and the directory says which.**
`tests/extended/` holds Extended Pascal sources; everything else is ISO 7185.
Every harness that walks the tree — `run_test.sh` through CMake, `difftest.sh`,
`irtest.sh` — derives the flag from the path, from one function each, so the
two compilers cannot be told different things about the same file.

**Word-symbols are reserved when the feature that needs them lands**, not all
at once. Reserving `value` before initial-state specifiers exist would reject
programs and buy nothing. This is a stated deviation: until the list is
complete, `--std=extended` accepts some programs a conforming processor would
reject. Each feature closes its own part of it.

**The stage-1 compiler reads the standard from a file.** ISO 7185 gives a
program no access to its command line beyond its program parameters, and those
are *files* — so `compiler.pas` cannot take a `--std` flag the way the C++
driver does. It takes a third program parameter instead, one word naming the
standard. This is the same shape of constraint that made ADR-0024 put the whole
compiler in one source file: the language the compiler is written in decides
its interface, and the honest response is to say so rather than to reach for a
mechanism ISO 7185 does not have.

**`otherwise` is the first feature.** ADR-0018 recorded that "`case` is an LLVM
switch whose default traps: ISO 7185 §6.8.3.5 has no `else` and none is
invented". Extended Pascal has one, so the note is now retired by the standard
rather than overridden by taste — which is exactly the bar CLAUDE.md sets for
stage 2. The lowering barely changes: an otherwise-part is *what the default
block holds*, not a different shape of switch.

## Consequences

**A one-token lookahead separates the construct from a constant.** Under ISO
7185 `otherwise` is an identifier, so `case x of otherwise: s end` is a label
list naming a constant — a legal program, and `tests/iso_identifiers.pas` runs
it. The parser tells the two apart by what follows: a case label is followed by
`:`, `,` or `..`, and an otherwise-part is not. That check is what lets the ISO
mode give a real diagnostic ("this is an Extended Pascal feature") instead of a
syntax error about a missing colon, without breaking the legal program.

**Two golden-test roots.** `tests/` and `tests/extended/` are globbed
separately by CMake and given different standards. A case cannot be in both,
which is right: a program using `otherwise` is not an ISO 7185 program.

**The differential test now covers both languages.** `difftest.sh` runs 207
files, and the Extended Pascal ones go through both compilers in extended mode.
That is the same discipline as before with one more axis: a stage that
disagrees about what `--std=extended` means fails there.

**Eleven mutations, eleven caught.** One escaped at first and it was the
oracle, not the corpus: the mutation that removes the ISO 7185 trap from a case
with no otherwise-part is caught by `tests/trap_case.pas`, which the harness had
not been told to run. Worth recording because it is the failure mode the
opposite way round from the usual one — a green result that means the check was
never asked, rather than a gap in what was asked about.

**What this does not decide.** How `string` and schemata arrive is untouched
here. ADR-0012 chose the length-plus-buffer record over Extended Pascal strings
partly because the project had not committed to that standard; it now has, so
that reason has expired — but ADR-0012's *finding* has not. A compiler reads
text in and writes text out, and measuring rather than guessing is what settled
it the first time. It should settle it again.
