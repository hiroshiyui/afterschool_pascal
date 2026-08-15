# ADR-0107: What the second independent reading found

## Status

Accepted.

## Context

ADR-0101 was the first run of `.claude/skills/langspec-audit/`: independent
readers given the behaviour and not the reasoning, told to prove the compiler
wrong from the standards text. This is the second, and it was aimed at a target
that did not exist the first time — **the thirteen clauses `tests/spec/` cites**
(ADR-0105), plus the clause triage that decides which clauses can carry a
scenario at all (ADR-0106).

The aim is what ADR-0105 said a scenario buys: a reading that is *findable*
becomes a reading that can be *attacked*. Seven readers, six over the cited
clauses and one over all 93 `structural` rows.

## Decision

**Forty-one behaviours audited. Thirty-seven CONFIRMED, two OVER-STRICT, two
UNDER-STRICT, one UNSETTLED — and eighteen clauses were misfiled in the
triage.** The corrections to `triage.tsv` land with this record; the four
compiler findings do not, and the reasons are below.

### The confirmations worth writing down

ADR-0105's own argument is that a reading which has survived an adversarial
check is a different thing from one that has merely not been challenged. Three
are worth naming because each *looks* wrong:

- **`succ` of a `1..9` holding 9 is 10, while `succ` of an enumeration's last
  constant is an error.** The asymmetry is the standard's: §6.6.6.4 makes the
  result "of the same type as that of the expression (see 6.7.1)" and §6.7.1's
  only sentence on the point promotes a subrange factor to its host. An
  enumerated type has no host, so the rule has nothing to rewrite. **BSI asserts
  both halves in one release** — CONF139 (CONFORMANCE) requires `pred` at a
  subrange's lower limit to yield a value outside it; ERR56T requires `succ` of
  an enumeration's last value to trap. A compiler that "fixed" the asymmetry in
  either direction fails one of them.
- **A variant part's labels must exhaust the tag-type exactly**, so
  `case tag: integer of 1: …; 2: …` is refused. §6.4.3.3's sentence is a set
  **equality**, not a membership test, and it is absent from Annex D — so
  §5.1 e) makes refusing it *mandatory* rather than optional. ADR-0096 argued
  this from DEV073's reclassification history; the audit adds DEV075, which
  states the rule in BSI's own words.
- **A `for`-statement's threat rule reaches a procedure that is never called.**
  BSI DEV224's threat sits inside `if 1 = 0` in an uncalled procedure, and its
  history records "V4.0: Body of nestedthreat altered to outwit optimising
  compilers" — the program exists to catch the shortcut this compiler does not
  take.

### The triage was wrong eighteen times, all in the dangerous direction

ADR-0106 said the triage is a reading and nothing here can check it. This is
what checking it found: eighteen clauses filed `structural` — "introduces the
subclauses below it; states no requirement of its own" — that state
requirements. The testable denominator moves **189 → 207** and the pending
queue **176 → 194**, so the reported figure *falls* from 8.1%/6.1% to
7.3%/5.6%. That is the honest direction and the reason the number is worth
having.

Two are worth naming for the shape of the mistake:

- **ISO/IEC 10206 §6.9.3.9.1 "General"** carries the *entire* control-variable
  rule set — declaration, ordinal type, nonbindable, undefined-after, and the
  threat rule. Everything ISO 7185 puts in §6.8.3.9, which was filed `testable`.
  Its own subclauses carry only the two iteration forms.
- **§6.4.1 was `structural` in ISO 7185 and `testable` in Extended Pascal** —
  one clause, two answers. Same for §6.6.3.1 against §6.7.3.1. **An internal
  inconsistency is the cheapest possible detector** and nothing was looking for
  it; a rule that the same heading in both standards gets the same class would
  have caught two of the eighteen for free.

The lesson is narrower than "read more carefully": a heading whose *title*
sounds structural is where a requirement hides, because "General" is exactly
what a clause is called when it carries the rule its subclauses elaborate.

### Four compiler findings, deliberately not fixed here

All four are recorded rather than acted on, because each is feature-sized and
this record is the audit's, not the fix's. **They are not deferred on merit** —
each carries a probe and a clause.

1. **A discriminant that is not a constant is refused outside a variable
   declaration** — `type t = vector(m)` and `var a: array [1..m] of real` inside
   a procedure, with `m` a value parameter. §6.2.3.8 b) puts "each
   actual-discriminant-part or subrange-bound **not contained by a
   schema-definition** and closest-contained by … the block" in the block's
   commencement, and orders it *after* the attribution of formal value
   parameters; §6.4.2.4 writes `subrange-bound = expression` and gives varying
   bounds their own dynamic-violation branch, which is meaningless if they are
   illegal. **ADR-0041 cited §6.2.3.2 as "the whole of the permission"; that
   clause is about what an activation *contains*, and the evaluation clause it
   never cites is §6.2.3.8 b).** This is the finding most likely to break a real
   program.
2. **An enumerated type inside a schema body is refused**, with a message
   arguing its constants "would be declared once per set of discriminants" —
   but §6.4.2.3 fixes the defining-point at the *block*, not the production.
   The witness is a schema whose domain holds exactly one tuple, where no
   ambiguity is even available. The multi-tuple case is genuinely unsettled
   between §6.4.1 and §6.4.2.3.
3. **A schema body may name a schema defined later** — accepted, and §6.2.2.9
   allows exactly two exceptions, neither of which is a record section. The
   compiler enforces the rule for plain type-names; schema bodies resolve
   lazily, at the first production, by which time the later definition exists.
4. **An unused self-referential schema is accepted.** §6.4.7's prohibition is
   about the schema-definition, not about productions, so the refusal firing
   only when a type is produced is one production too late.

### One UNSETTLED, resolved in the compiler's favour and left alone

`packed array [lo..hi] of char` produced with `lo = 1` is treated as a
string-type. Literally, §6.4.3.3.2 requires the first subrange-bound's
expression to contain no discriminant-identifier, and `lo` is one. But §6.4.7
defines production as *substitution*, and after substitution the denoter is
`packed array [1..5] of char`. The substitution reading gives both clauses work;
the literal one makes §6.4.3.3.2's discriminant clause vacuous for produced
types while refusing them. **No scenario is written for it** — the suite states
what the standard requires, and a scenario asserting one of two defensible
readings would launder a coin-flip into a citation.

## Consequences

**Isolation failed on all seven readers, identically, and the audit is still
worth what it cost.** The harness injects `CLAUDE.md` — including the ADR
summaries for the clauses under audit — before a reader's first turn, and none
could decline it. Every one disclosed it unprompted, which is what the skill
demands and the reason it demands it. What makes the output usable anyway:

- The **confirmations rest on BSI**, an artefact from 1982 that nobody here
  wrote, and on clause text quoted verbatim and re-verified against the PDFs.
  A reader's *agreement* with `CLAUDE.md` is worth nothing on its own.
- The **disagreements are the least contaminated part**, because they are
  contrary to the injected text. All four compiler findings and all eighteen
  triage corrections are disagreements.
- One reader made the sharpest observation about its own position: several of
  its findings are clauses the injected document *discusses at length without
  naming the clause number*, so the injected text argued for the requirement and
  against the filing.

**This is a property of running the skill in-process, not of its instructions**,
which already say isolation is not guaranteed. It bounds what a run can claim: a
CONFIRMED verdict here means "no independent oracle contradicts it", not "an
uninfluenced reader agreed".

**A reader corrected the brief, which is the audit working in an unplanned
direction.** The description of the string-type predicate given to reader 5 was
incomplete: ISO/IEC 10206 §6.4.3.3.2 does not merely *drop* ISO 7185's
largest-value requirement, it *adds* two — the first subrange-bound must be
nonvarying and must contain no discriminant-identifier. Both are implemented;
neither was in the behaviour list the reader was asked to attack. A brief
written from the code inherits the code's blind spots.

**Two readers found nothing, and that is a result.** The arithmetic and
case-statement clauses, and the string clauses, came back with twenty
CONFIRMED verdicts and no defect, over probes including exhaustive `div`/`mod`
grids and both of ISO/IEC 10206 §6.9.3.5's own Examples transcribed verbatim and
run. The reported nuance is worth keeping: **overflow detection is permitted,
never required** — §3.1 makes it an error and §5.1 f) offers three treatments —
so no document here may say the standard obliges the trap. `doc/implementation-
defined.md` was checked and does not.
