# ADR-0162: What an adversarial reading of the standards found

Date: 2026-08-22

## Status

Accepted. The second run of `.claude/skills/langspec-audit/`; ADR-0101 and
ADR-0107 record the first.

## Context

No oracle in this repository can contradict a **reading**. The goldens agree
with whoever wrote them, `tests/bsi/expected.tsv` records what this compiler
does, `verify/` proves the lowering matches a model of the lowering, and
`difftest`'s two front ends are written by one author from one reading — which
is how ADR-0073's comment-delimiter rule came to be wrong in both. `tests/spec/`
makes a reading *findable* under its clause; ADR-0105 says in its own Decision
that this does not make it *checked*.

Three readers were given the standards and the compiler's behaviour, told the
reasoning was off limits, and asked to prove a misreading. Their groups:

1. ISO 7185 §6.6.3.7, §6.6.3.8, §6.6.3.6 e) and clause 5.1 — conformant array
   parameters and the level claim (ADR-0153, the largest recent conformance
   feature).
2. What the two conformance modes *say* about the five dialect constructs —
   §6.6.3.1, §6.1.4, §6.2.2.10, §6.1.1, and Extended Pascal's substring clauses.
3. `tests/spec/clauses/triage.tsv`'s `structural` and `not-implemented` rows,
   which ADR-0106 says nothing here can check.

**Independence was not achieved and all three said so.** The harness injects
`CLAUDE.md` before a reader can decline; all three disclosed it, one disclosed
reading seven lines of `doc/design-digest.md` to confirm a grep hit. So a
CONFIRMED verdict here means "no independent oracle contradicted it", not "an
uninfluenced reader agreed" — the same caveat ADR-0107 records, unchanged. Every
quotation below was re-checked against the PDFs by the adjudicator before any
change was made.

## Decision

### Confirmed, and this is most of what the audit produced

**§6.6.3.7 and §6.6.3.8 are implemented sentence by sentence**, attacked with
~70 probes and the whole BSI LEVEL1 category (51 programs, categories
re-derived from BSI's own headers rather than from this project's catalogue).
All 16 `CLASS=CONFORMANCE` programs compile, run and print PASS; all 27
DEVIANCE programs are refused, and each for the clause its header names. The
two readings that separate a correct implementation from a plausible one both
hold: NOTE 3's "the type possessed by the formal-parameter cannot be a
string-type", and §6.6.3.7.2's a)/b) occurrence rule, where `r(a[i])` is legal
when `a[i]` **is** the fixed-component-type and illegal when it is an array.
Five scenarios now cite §6.6.3.7 and §6.6.3.8.

**The five refusals of the dialect's constructs are correct and are the right
*kind* of refusal.** None is an §3.1 error — none needs knowledge of data read
by the program — so §5.1 e) makes reporting them compulsory rather than
optional. `external` is named by both standards **only** in an informative NOTE
as an extension, and neither reserves the spelling, so `var external: integer`
still compiles under both conformance modes. `?` is settled not by §6.1.1 but by
clause 4: "The characters required to form Pascal programs shall be those
implicitly required to form the tokens and separators defined in 6.1." The
substring restriction is exact — §6.5.3.2's string-variable must possess a
string-type, §6.4.3.3.1 gives three and an array of integer is none.

### Fixed

- **The parameter-type diagnostic misstated the rule** for this processor's own
  level: `a parameter's type must be a type name` has been false since
  conformant array parameters landed. Widened, in both front ends.
- **The clause 5.1 compliance statement was not in the prescribed terms.**
  Clause 5.1 says a processor purporting to comply "shall do so only in the
  following terms" and gives the sentence; the document said "This processor
  complies at level 1", keeping the standard's own placeholder text where an
  unambiguous name belongs. Both statements written out, in the "with the
  following exceptions" form, §6 of that document recording restrictions.
- **`doc/design-digest.md` still said level 0.**
- **Ten triage rows filed conformant array parameters `not-implemented, this
  processor is level 0`,** citing a document whose first line says level 1 —
  so ten clauses of a shipped feature were outside the denominator and the work
  queue, and a scenario citing one *failed* the gate. Reclassified.
- **Four clauses filed `structural` state requirements**, including
  §6.2.2.13's "No module shall supply its module-heading", the acyclicity rule
  for interface import, stated nowhere else.

### Unsettled

**Whether HT, VT and FF are separators.** `IsSpace` admits ordinals 9–13
outside strings and comments. §6.1.8 gives the separators as "comments, spaces
(except in character-strings), and the separations of consecutive lines"; LF and
CR are the third, and HT, VT and FF are obviously none of the three — while
clause 4 makes the required characters those needed to form the tokens and
separators of §6.1. So the lexer refuses `?` on a rule it does not apply to a
tab. No reader found a sentence settling it, universal practice is to accept a
tab, and no program breaks either way. It gets no scenario: the suite states
what the standard requires, and asserting one of two defensible readings would
launder a coin-flip into a citation.

## Consequences

The audit found **no misreading of either standard**. That is the outcome worth
recording, because it is not the outcome the first run had — ADR-0101 found
three under-strict gaps — and because a reading that has survived an
adversarial check is a different thing from one that has merely not been
challenged. What it found instead was five defects in the *documents and
machinery* around the readings, which is where ADR-0152 found its 37.

**BSI's catalogue was re-verified wholesale**: one reader ran all 812 programs
rather than trusting `expected.tsv`, and all 812 agree. Exactly one
`CLASS=CONFORMANCE` program of 236 is refused — `CONF068`, §6.4.3.4, a file as a
field of a variant part, refused deliberately under ADR-0070. **That is the only
place in the suite where over-strictness could still be hiding**, it was outside
every reader's brief, and it is the obvious target for the next run of this
skill.

## What this does not do

- **It does not make the readings independent.** All three readers were exposed
  to `CLAUDE.md`. The verdicts are worth having and are not what an uninfluenced
  reader would have produced.
- **It audited about 20 of 130 `structural` triage rows.** Two of the four
  wrong ones came from one reason string that 54 rows share, and both were
  Extended Pascal clauses that gained a sentence their ISO 7185 namesake lacks —
  which is the shape to look for. `doc/sop.md` §7 carries the other 50.
- **It says nothing about the dialect**, deliberately: `--std=afterschool` was
  out of scope for all three readers, and its specification is audited by
  ADR-0144's own run.
- **It did not check §6.6.3.7.1's "accessed before the activation of the
  block"**, which no conforming program can observe, nor the empty conformant
  array, which §6.4.2.4 makes unconstructible.
