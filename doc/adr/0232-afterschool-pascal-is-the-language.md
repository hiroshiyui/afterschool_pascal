# 232. Afterschool Pascal is the language

Date: 2026-08-28

## Status

Accepted. Retires `--std`, the two conformance modes, ADR-0166's `{ @std: }`
header comment, and the clause 5.1 a) compliance statement. Supersedes
ADR-0033's non-nesting arrangement, ADR-0165's default, and the part of
ADR-0117 that made the dialect a third mode beside two others.

## Context

This compiler was built to conform. ISO 7185 came first, ISO/IEC 10206:1991
after it, and both were finished — `--std=iso7185` and `--std=extended` select
them, and ADR-0117 added `--std=afterschool` for the dialect ADR-0109 has been
aiming at since. The conformance modes have been described here as "not going
anywhere".

The goal was never conformance for its own sake. README has said for a long
time that the long-term aim is *"a Pascal you can get work done in"*, and every
increment since ADR-0114 has been dialect work. What had not been settled is
what this project **is** while that work goes on: a conforming processor with a
dialect attached, or a Pascal dialect with two compatibility modes attached.

It is the latter, and this record makes the compiler say so. Afterschool Pascal
is a Pascal dialect in the sense Turbo Pascal and Free Pascal are: the syntax
is Pascal, and no standard governs it.

## Decision

**There is one language and it is Afterschool Pascal.** `--std` is removed, and
with it `stdKind`, `langStd`, `HasExtended`, the `{ @std:iso7185 }` header
comment, the `.std` sidecars and `selfhost/compiler.std`. A source is written
in Afterschool Pascal, and the compiler has no mode to be put into.

The lexis is the dialect's: ISO/IEC 10206:1991's thirteen additional
word-symbols are reserved, because the dialect contains Extended Pascal
(ADR-0117) and that containment is what makes the change survivable at all.

## Consequences

**This was measured before it was decided, and the measurement is the reason
the record is long.**

*The Extended Pascal corpus is unaffected.* The dialect contains it, and
`dialect-containment` has swept 281 cases on every run to prove it. Twenty-six
exceptions exist and every one is a `*_refused` case — a program asserting that
a dialect construct is rejected under Extended Pascal. Their subject
disappears with the modes.

*The ISO 7185 corpus does not survive intact.* Of 172 cases run as dialect
programs:

| | |
| --- | --- |
| pass unchanged | 109 |
| **refused outright — the program cannot be expressed** | **25** |
| compile but behave differently | 38 |

**The 25 are the cost that cannot be paid back.** ISO 7185 and Extended Pascal
are *not nested* (ADR-0033): §6.1.2 reserves thirteen word-symbols that a
conforming ISO 7185 program may use as identifiers. A record with a field
called `value` is a conforming ISO 7185 program and is now a syntax error with
no flag to rescue it. In this corpus alone `value` appears in 60 files, `only`
in 61, `otherwise` in 12.

BSI's **CONF005** is the sharpest case, and it is not ours: BSI wrote it in
1982 to check that a conforming processor still accepts `module` and
`restricted` as identifiers. It is the one program of 812 that only the older
mode compiles, and under one language it cannot pass — not because it stopped
being run, but because the language can no longer express it.

**Five oracles retire, and nothing replaces them.** This is the larger loss and
it is worth stating without softening, because `doc/roadmap.md`'s open question
§1 already records that *every* oracle here bottoms out in "the standard says
X":

- **the BSI Pascal Validation Suite** — 812 programs from 1982, the only
  artefact in this repository that nobody here wrote, and the only third-party
  corpus the project has ever had;
- **`difftest`** — `src/` is frozen at the conformance surface and dialect
  sources are already skipped, so with no conformance surface there is nothing
  for two implementations to disagree about;
- **`dialect-containment`** — the conformance corpus compiled a second way,
  which the roadmap calls "the nearest thing to a second reading the dialect
  can have";
- **`annex-b`** — the refusal surface is *conformance* behaviour by
  construction (ADR-0121, ADR-0154), and there is no conformance mode to refuse
  anything;
- **`reserved-words`** — asks that the dialect reserves exactly what Extended
  Pascal reserves, which is not a question once there is nothing to compare to.

The oracle table in open question §1 had one empty row, the dialect's. It now
has only that row.

**The compliance statement is withdrawn, not reworded.** Clause 5.1 a) requires
a processor to state which standard it conforms to and at what level;
`doc/implementation-defined.md` claimed ISO 7185 level 1. A processor that
cannot compile CONF005 does not conform, and saying otherwise would be the one
kind of false claim this project has been most careful about. What the document
keeps is its §6 restrictions list, which is a useful description of a dialect
whether or not a standard demands it.

**`tests/spec/` loses its two-standard structure.** 27 `@iso7185:` and 57
`@extended:` scenarios cite clauses of documents this compiler no longer
implements. The clause triage, the inventories and `pending.txt` are all keyed
on the two standards.

**What is kept, and why it is worth keeping.** The standards remain the source
of the *design*. Every clause reading, every ADR, every scenario that describes
behaviour the dialect inherits is still true of the dialect, because the
dialect contains Extended Pascal. What changes is that they are no longer
*obligations* — they are where the language came from.

## Alternatives rejected

**Make the dialect the default and keep the modes.** This was recommended and
declined. It delivers an unflagged `pascalc prog.pas` compiling Afterschool
Pascal, keeps every oracle above, keeps ISO 7185 expressible through
`--std=iso7185` or ADR-0166's header comment, and costs none of the three
losses recorded here. It was rejected because it leaves the project still
presenting itself as a conformance vehicle with a dialect attached, which is
not what it is. The default flip was made first and is subsumed by this record.

**Keep an ISO mode the way Free Pascal keeps `{$MODE ISO}`.** The nearest
precedent, and Free Pascal is a dialect by any measure. Rejected for the same
reason: a mode is a claim about what the compiler is for, and this project's
answer is now one language.

**Keep the modes but stop testing them.** The worst of both — the flags would
remain and would silently rot, which is what `doc/sop.md` §7 exists to prevent.
A capability nothing checks is a capability nobody should rely on.
