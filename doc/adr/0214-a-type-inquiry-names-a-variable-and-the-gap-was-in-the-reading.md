# 214. A type-inquiry names a variable, and the gap was in the reading

Date: 2026-08-27

## Status

Accepted.

## Context

ADR-0213 closed with the container module written, and with two things it had
found written down. One of them was wrong.

`doc/roadmap.md` gained an entry under *Known limitations — Under
ISO/IEC 10206:1991* saying:

> **§6.4.9's type-inquiry-object is a variable-access, and this compiler
> accepts only a name.** `type of v` works; `type of r.f`, `type of a[1]` and
> `type of p^` are refused, the last two as *parse* errors. […] *A fix, and one
> with no record yet.*

It is not a variable-access. §6.4.9 reads:

```
type-inquiry        = 'type' 'of' type-inquiry-object .
type-inquiry-object = variable-name | parameter-identifier .
```

and §6.5.1 defines the first alternative:

```
variable-name = [ imported-interface-identifier '.' ] variable-identifier .
```

A **name**, with one optional qualifier and only before an imported interface.
The other five variable-accesses — an indexed-variable, a field-designator, an
identified-variable, a buffer-variable and a substring — are not among them.
So the three programs the entry called refused-in-error are refused correctly,
and a processor that accepted them under `--std=extended` would be the one with
the defect. The entry pointed at the wrong side of the line.

**ADR-0047 has quoted the production correctly since the feature landed**, four
lines into its Context, and the compiler's own comment says `variable-name` in
both front ends. The entry contradicted a record and two sources without
anything noticing, and stood for a day.

### Why nothing here could see it

This is the blind spot `CLAUDE.md` names, and it is worth being exact about
which oracles were asked and what each of them said.

| Oracle | What it said |
| --- | --- |
| the whole `ctest` suite | green — the compiler was never changed |
| `difftest` | agreed — both front ends implement the clause the same, correct way |
| `clause-citations` | passed — §6.4.9 is a real clause, which is the cheap half it advertises (ADR-0164) |
| `spec-clause-traceability` | passed — the roadmap is not a scenario |
| the eleven corpus uses of `type of` | all name a simple variable, so none contradicts either reading |

Every gate was answering a different question. A false claim about what a
*standard* requires, written in prose, is the one thing here nothing can
contradict — ADR-0072's set-packing deviation is the same shape, and it
survived in four documents and a purpose-written test.

**The route in is the part to keep.** The entry was not written by misreading
§6.4.9; it was written by not reading it. The wish came first — a generic call
in `lib/dialect/pascontainer.pas` passes an element type the container's type
already knows, and `x: type of v^.a[1]` would remove it — and the clause was
then described from what the wish needed. That is why it named the grammar so
confidently and so wrongly: *variable-access* is what the wish requires, and
the sentence was generated from the requirement rather than from the document.

## Decision

**§6.4.9's type-inquiry-object is a variable-name or a parameter-identifier,
and this compiler is conformant.** The roadmap entry is struck, in its own
place and in the container row that repeated it, and both strikings say what
they used to say — a correction that erases its own subject teaches nobody.

**What the episode leaves is a diagnostic**, and it is the only code change
here. The three refusals were correct and said so poorly:

| written | before | now |
| --- | --- | --- |
| `type of a[1]` | `expected ';' after a variable declaration, found '['` | `'type of' names a whole variable, not a component of one` |
| `type of p^` | `expected ';' after a variable declaration, found '^'` | the same |
| `type of r.f` | `unknown variable 'f' in 'type of'` | the same |

The first two named the declaration's own semicolon; the third reported a field
as an undeclared variable. All three now name the rule and the construct. **No
program's acceptance changes** — this moves nothing across the line, which is
what makes it a diagnostic and not a language change, and it needs no Annex B
row for the same reason.

**It is two tests, because the two spellings of a field-designator part
company.** `type of a[1]`, `type of p^` and a *second* period are refused by
the parser, where a bracket, a caret or a period after the object cannot begin
anything a type-inquiry may be followed by. `type of r.f` is not: the parser
has one production for a qualified name and cannot tell an imported interface
from a record variable, so it consumes `r.f` and Sema asks the symbol — the
recurring answer *ask the symbol, not the syntax*, for the sixth time. Both
front ends carry both halves, so `difftest` compares them.

**The wish is a dialect question and is not decided here.** It is open question
4 in `doc/roadmap.md`, with the argument for it (the spelling is free — `type
of` is a position the dialect already holds, so ADR-0184's shape applies and
ADR-0140 needs no argument), the cost (a designator whose type is computed
without evaluating it, inside re-entrant declaration checking, re-entered per
generic instantiation since ADR-0211), and the reason to wait (it makes one
formal's type depend on a designator over another, and a constraint system
might subsume it).

## Consequences

**A clause number written in this tree is a citation, and a clause *quotation*
is a claim nothing checks.** `clause-citations` proves a number names a clause
of some standard and says in its own description that it never asks whether it
names the right one. This is the next case out: the number was right, the
clause was named right, and the production quoted under it was invented. No
gate is proposed for it — a grammar-quotation checker would need the standards'
text, which may not be in this repository (`tests/spec/`'s own rule), and the
`.tsv` inventories carry numbers and headings and nothing more.

What is available instead is the habit `CLAUDE.md` already states for
completeness claims — *before asserting completeness of anything, compile a
probe for the clause* — extended one step: **before recording a limitation,
read the clause it is about.** A limitation is a claim about a standard exactly
as a completeness claim is, and this is the first one here to be wrong. The
probe existed and was not written; writing it took four files and five minutes,
and produced the diagnostics above as a side effect.

**The commit message of `1360ae5` carries it too, and stays as it is.** The
claim was written three times on one day — the roadmap's *Known limitations*,
the roadmap's container row, and the `feat:` message that landed
`lib/dialect/pascontainer.pas` — and only the two documents can be corrected.
That is the same answer `CLAUDE.md` gives for the eight features whose README
edits landed inside their `feat:` commits: published history is not rewritten
to repair a claim, it is superseded by a record that says so. This is the
record; grepping `git log` for the sentence finds the commit, and the commit's
own subject leads here through the container row.

**`doc/vendor/` is how it was settled**, in twenty seconds, and that is worth
recording because the directory is gitignored and easy to forget: the standards
are on disk, `pdftotext` reads them, and no clone that lacks them can settle a
question like this one at all.

**Cost.** Two small refusals, one in each front end, plus one Sema branch in
each; three new cases and one existing case extended. The parser test is three
tokens and can only fire where a type-denoter has already been completed, so it
cannot reject anything a conforming program writes — `dialect-containment` and
the two conformance corpora are the evidence.

**What was rejected.** *Leaving the diagnostics alone and only striking the
entry* — the messages are why the entry read as plausible, and a reader who
writes `type of a[1]` is still told about a semicolon. *Implementing the
variable-access form under `--std=extended`* — that is the defect the entry
described, inverted; an extension inside a conformance mode is a defect unless
`doc/implementation-defined.md` lists it, and this one would have no reason to
be listed. *Adding it to the dialect in this record* — the reason is real and
the spelling is free, but it is a language decision on the back of a
correction, and ADR-0109's dialect takes features on their own argument.
