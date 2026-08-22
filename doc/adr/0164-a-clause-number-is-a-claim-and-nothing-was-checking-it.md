# 164. A clause number is a claim, and nothing was checking it

Date: 2026-08-22

## Status

Accepted.

## Context

ADR-0163 corrected a citation that had spread to four living places, and the
question it raised is whether that was bad luck or a pattern. It is a pattern,
and the measurement is worse than the anecdote.

**The two standards agree on 46 of the 91 clause numbers they share, and
disagree on 45.** Extended Pascal inserts String-types at 6.4.3.3 and every
number below it shifts by one. So a bare number is a coin flip wherever the
context does not say which standard is meant:

| number | ISO 7185 | ISO/IEC 10206:1991 |
| --- | --- | --- |
| 6.4.3.3 | Record-types | String-types |
| 6.4.3.4 | Set-types | **Record-types** |
| 6.4.7 | *Example of a type-definition-part* | **Schema-definitions** |
| 6.9.4 | The procedure `writeln` | **Threats** |
| 6.10 | Programs | Input and output |

There are **825** citations of one of those 45 numbers outside `doc/adr/`. A
rule requiring every one of them to name its standard would be a mass edit of
sites that are unambiguous in context, and would say nothing about whether the
number was right.

**A citation is the one claim here that no oracle can contradict.** A wrong
clause number compiles, runs, passes every golden, agrees with the other front
end, and is proved correct by `verify/`. ADR-0072 is the record of one
surviving in four documents and a purpose-written test.
`spec-clause-traceability` gates the clause **tags** in `tests/spec/`, and a
prose citation is not a tag; nothing had ever looked at the other four
thousand.

Counting them found two numbers, of 7336 citations, that name no clause of
either standard or of the dialect specification.

**`6.8.3.11` names nothing, and had stood in seven places** — `CLAUDE.md`,
`runtime/pasrt.c`, `doc/roadmap.md`, `tests/checks/nonstandard_c.txt`,
`tests/dialect/foreign_libm.pas`, a released `CHANGELOG.md` entry, and
ADR-0161. Every one of them glossed it as "the non-local goto". ISO 7185
numbers the goto-statement **6.8.2.4** and stops its structured statements at
6.8.3.10; Extended Pascal uses 6.8.3.x for *Operators* and numbers the goto
**6.9.2.4**. The repository cites 6.8.3.9 for the for-statement and 6.8.1 for
the goto-target rule, both correct, which is how a wrong neighbour went
unnoticed for so long.

**`6.6.4.1` is subtler and is not our error.** ISO 7185's 6.6.4 is four lines
and a NOTE, followed directly by 6.6.5; there is no such subclause. But
6.2.2.10 reads

> Required identifiers that denote required values, types, procedures, and
> functions shall be used as if their defining-points have a region enclosing
> the program (see 6.1.3, 6.3, 6.4.1, and 6.6.4.1).

and the index lists 6.6.4.1 twice. **The standard has a dangling
cross-reference and this repository inherited it**, in 25 places, for a rule
that is real and is 6.2.2.10's. Nearly filing that as a defect is the same
mistake as reading BSI's LEVEL1 directory as a class: the number looked wrong
and was the standard's own.

## Decision

**A gate asks whether a cited number names a clause at all**, against the
generated inventories, and nothing more. `tests/checks/clause_citations.py`,
7382 citations over 1346 files, a `ctest` case so it runs before a push.

**It walks the tree rather than asking git.** The first version asked
`git ls-files --cached --others --exclude-standard`, which is the more precise
question and which **exits 128 in a container** whose checkout git calls
dubiously owned — three CI jobs, and a gate that cannot run is worse than one
that is merely narrow. What the walk gives up is `.gitignore`, so the four
directories that must not be read are named in the source with the reason
apiece: `doc/vendor/`, which is the standards' own text and may never be
scanned or committed; `tests/bsi/suite/`, whose headers cite clauses in BSI's
numbering and are not ours to correct; `build*/`; and `__pycache__`. What it
keeps is reaching a file that has not been added yet, which is the moment a
citation can still be fixed without a catalogue entry.

**It answers the cheap half and the file says so.** It cannot ask whether a
number names the *right* clause, so it would not have caught ADR-0163 — 6.4.3.4
exists in both standards, meaning two different things. That half needs a
reader, and `langspec-audit` is where it lives. What this catches is the number
that names nothing, which is the failure that can persist indefinitely because
no reader chasing it ever arrives anywhere to be surprised.

**A clause number written in this tree is a citation, and the gate cannot tell
a mention from a claim.** That is the rule and not a limitation: a document
discussing a wrong number either avoids spelling it or takes a catalogue entry.
This record takes one, which is the honest form of the constraint.

**The catalogue is per number and per file, with the argument in prose**, as
`uncovered_procedures.txt` and `unreachable_diagnostics.txt` are. It fails in
four directions, each demonstrated before it was committed: a citation naming
nothing; an entry for a number that is a clause after all; an entry naming a
file that no longer cites it; an `anywhere` entry cited nowhere.

**An entry is a claim about the standard, not about the inventory.** The
inventories are generated, and ADR-0152 found 37 real clauses in none of them
because the extractor read only lines carrying a title — 6.2.2.10, the clause
quoted above, is exactly that shape. So the catalogue's header says to check
the standard before adding an entry, and 6.6.4.1's entry quotes the sentence
that settles it.

**The correction does not touch the accepted records.** ADR-0001 makes them
immutable and a citation error is not grounds for an exception: ADR-0161 keeps
its wrong number and this record is where a reader learns of it. Two catalogue
entries say so, one for ADR-0161 and one for the released `CHANGELOG.md` entry,
which that file's own header keeps as written.

## Consequences

Five living sites were corrected to name both numbers —
`ISO 7185 §6.8.2.4 / ISO/IEC 10206:1991 §6.9.2.4` — which is the form
`CLAUDE.md` had already used once for §6.8.1 and is now the house style for an
ambiguous number.

### What this does not do

**It does not check that a citation names the right clause**, and no gate here
can. That is `langspec-audit`'s work and the reason ADR-0107 exists.

**It does not require a citation to name its standard.** 825 sites cite one of
the 45 ambiguous numbers, most unambiguously in context, and a ratchet over
them would be a large ongoing cost for a claim it cannot verify. What is
adopted instead is a **convention**, stated in `doc/sop.md`: where the
surrounding text does not pin the standard, name it. `doc/sop.md` §7 carries
the gap.

**It does not read Annex D, Annex A, or the dialect spec's own annexes**, whose
numbering is not clause 6's. The pattern matches numbers beginning `6.` alone,
which is what keeps 7336 citations down to three unknown — the third being
6.2831853071795864769, two pi, in the runtime.
