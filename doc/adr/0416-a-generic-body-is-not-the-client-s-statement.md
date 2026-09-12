# ADR-0416: A generic's body is not the client's statement to answer for

## Status

Accepted.

## Context

ADR-0350 made `lib-coverage` measure `lib/` by instrumenting **one module per
link**, because `$PASCOV_LINES` is bare line numbers and a program linking six
modules would otherwise yield six sources' lines in one heap. The denominator
comes from the same IR the numerator does: every `pas_cov_hit(i32 N)` the
instrumented module emits, as a set of line numbers.

A generic's body is emitted in the translation that **activates** it
(AP 6.7.3.5), so a client of `PasContainer` carries `VecPush`, `VecGet` and
five more in its own IR — with `PasContainer`'s line numbers. Those index into
the client's source and land on whatever text is at that line: a comment, a
blank, a field declaration.

The effect was measured rather than guessed. Across the 33 modules, **479
routines are a module's own and 28 are instantiations**, the same seven `Vec`
routines in the four modules that use them, and they contributed **50
statements** to the denominator — 18 of them in `pastoml.pas` alone, and 18 in
`paslspdiag.pas`, where they were reported as *uncovered* because that
module's corpus never runs them.

Worse than the inflation is the instability. Another file's numbering collides
with this file's wherever the two happen to coincide, so the denominator moved
whenever a module's **length** changed. It moved three times in one day for
edits that touched no statement, twice of them for a comment, and each needed a
commit message to establish that nothing had happened:

- `78fbdd2` — `pastoml.pas` 928 → 921, argued by arithmetic;
- `3ccefdd` — the same module 921 → 924, a six-line comment;
- `c2708ec` — `paslsp.pas` 147 → 149, nineteen lines longer.

A ratchet that moves for a comment is a ratchet people learn to regenerate
without reading, which is the one thing this project says about ratchets that
must not become false.

## Decision

**A module's denominator is the statements of its own routines.** The IR writes
`; name line` before each routine (ADR-0103); a routine is this module's when
that marker points at a line of this source that *declares* that routine, and
a foreign one points wherever its own file's numbering falls. Hits are walked
in order and attributed to the routine whose marker last opened.

Two other separators were tried against the corpus and rejected on evidence:
the LLVM name does not work, because a module's own **private** routines are
`internal` and counter-named exactly as an instantiation is (`@p58` beside
`@p134`); and a ratio of dropped to kept does not work, because
`paslspdiag.pas` has six routines of its own and seven instantiations, which
is legitimate and fails any ratio worth setting.

**The check on the rule is that a dropped name is not declared in this source
at all.** A routine wrongly dropped is one whose declaration is right there; a
generic's is in the module that wrote it. That is exact, needs no threshold,
and fails with the name it found. The gate also reports what it dropped, every
run, because a statement excluded from a denominator is one nothing will ever
be asked about.

## Consequences

- The ratchet is corrected once: 3560 instrumented statements to **3510**, and
  386 uncovered to 364. `pasjson.pas` 408 → 397, `paslsp.pas` 149 → 143,
  `paslspdiag.pas` 96 → 78, `pastoml.pas` 924 → 910, and no other module moves.
  `paslspdiag.pas`'s uncovered count goes 20 → 2, because eighteen of the
  lines it was failing to cover were never its statements.
- The gate prints the instantiations it excluded — 28 across four modules —
  rather than silently omitting them.
- **The stability is the evidence**: adding three lines of comment to
  `pastoml.pas` moved the denominator before this change and does not after.
  Two mutations beside it — the old attribution restored, which puts the 50
  statements back and fails the ratchet; and a single routine wrongly dropped,
  which the declaration check names.
- A module that gains a generic client gains no phantom statements, which is
  the future this constrains: `PasContainer` is the substrate of five
  converted containers (ADR-0413) and every one of them was carrying its
  bodies.

## Alternatives rejected

**Count emitted counters rather than distinct lines.** It answers the *did the
statements change* question outright — 181 calls before and after, which is how
`c2708ec` was settled — and cannot be the denominator, because the numerator is
line numbers: `$PASCOV_LINES` records lines and two statements on one line are
one line at run time. It stays the right instrument for the question it
answers and is named in the commit that used it.

**Emit the owning file with the coverage marker.** Exact, and it puts the
answer in the compiler instead of a reader of its output. Rejected for now on
cost and blast radius: the marker is written by CodeGen, which is a modelled
region, so it would need `verify/` touched or a trailer arguing it, for a
correction a gate can make on its own. Worth revisiting if a second gate needs
the same attribution.

**Leave it and keep explaining.** Three commit messages in one day were spent
establishing that nothing had happened. The fourth would have been spent the
same way.
