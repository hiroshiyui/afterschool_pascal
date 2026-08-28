# 234. A second processor answers the corpus

Date: 2026-08-28

## Status

Accepted, 2026-08-28.

It discharges the *task* half of [open question §2](../roadmap.md) and leaves
[§1](../roadmap.md) exactly where it was: §1 is a standing risk about
authority and no gate can close it. It supersedes no record. It is the first
oracle added here since ADR-0189, and the second in this tree that this
project did not write.

## Context

Every program in `tests/` has exactly one reader. That was not always true —
`difftest` compared two front ends and the BSI Pascal Validation Suite was 812
programs somebody else wrote — and ADR-0232 retired both, the first with the
conformance surface `src/` was frozen at and the second because 25 of its
programs use a word-symbol this language now reserves. What was left was
`unicode-conformance`, which reaches one clause.

The roadmap has carried the remedy as an open question since before v3, in one
sentence that has never changed: *a second answer, on programs that already
exist*. Not a second implementation to maintain. It also carried the reason to
stop deferring it — **the option closes as the language diverges**, because
nobody else implements this dialect, and every release makes the reachable
corpus smaller.

Two things had to be established before the work was worth anything, and both
were measured rather than assumed:

- **Free Pascal 3.2.2 accepts `-Miso` and runs an ISO 7185 program.** It does.
- **`-Mextendedpascal` does not implement §6.13's modules.** `module m
  interface;` is *"Syntax error, BEGIN expected"*. So the eight conforming
  modules in `lib/` — which the roadmap named first, as the portable half —
  are **out of reach**, and the differential is over programs alone. That is
  the estimate this record corrects: §2 said a second Extended Pascal
  processor could run those, and none can.

## Decision

`tests/checks/fpc_differential.py` compiles every case in `tests/` and
`tests/extended/` that has a `.out`, with `fpc -Miso` falling back to
`-Mextendedpascal`, runs it, and compares. It is a `ctest` case that **skips
77** without `fpc` — which is not a documented dependency and must not become
one — with `FPC_DIFFERENTIAL_REQUIRE` to make a skip a failure where a job
means to run it.

**What is compared is not bytes.** ISO 7185 §6.9.3.1 leaves the default
TotalWidth to the processor and §6.9.3.4.1 leaves ExpDigits and the exponent
character; FPC writes an integer in eleven columns and an exponent in three
digits where this compiler writes the fewest it can and two. Comparing those
would be comparing two permitted answers and would bury everything else: a
byte comparison leaves **64** of the 103 comparable cases differing, and 11
survive once the permitted spellings and the two classes below are set
aside. So numbers compare **by value** and
blanks are dropped, which also handles the case that makes a naive
normalisation fail: a boolean written next to another with no separator turns
the padding into a space *inside* a run, and `truefalsetrue` and
`truefalse true` are the same answer.

**Two classes of disagreement are one fact and are counted, not listed.** An
ISO error this compiler traps (ADR-0014, ADR-0015) and FPC runs past — the
golden stops at the trap and FPC's output extends it — and a program whose
parameters name files, which the two processors bind differently. Twenty-six
cases, and listing them per case would say the same sentence twenty-six times.

**Everything else is catalogued**, in `tests/checks/fpc_disagreements.txt`,
and an entry has to say **which clause decides it and which way**. Eleven
entries. The catalogue fails in **both** directions, as every catalogue here
does — and the direction that matters is the second: a disagreement that stops
happening means somebody changed an answer this file explains, and it was
either this compiler or a new FPC.

## Consequences

**The differential found no defect in this compiler**, and that is the result
rather than a disappointment to be written around. Of the eleven catalogued
disagreements, six turn on a clause and all six are decided here — §6.1.8
NOTE 1's mixed comment delimiters, §6.6.6.3's definition of `round` by
equivalence, §6.9.1's longest-prefix number read, §6.6.5.2's appended
terminator, §6.9.5's unconditional form feed, and §6.10.3.4.2's unconditional
decimal point. Two are implementation-defined, where neither processor is
wrong. Three are not verdicts at all, one of them a case that **cannot** be
compared and says so.

**Three of the six corroborate a reading nothing here could previously
challenge**, which is the whole of what a second processor buys:

- ADR-0073's mixed comment delimiters. That record says in as many words that
  nothing here could have caught the defect — a comment is invisible to every
  stage after the lexer, so the dumps `difftest` compared would have agreed
  whatever a comment did. FPC totals 27 where the clause gives 31.
- `tests/round_equivalence`, where the test's own comment predicted the
  disagreement — *"a processor emitting a round-half-away-from-zero
  instruction answers 0"* — and FPC answers 0. The prediction had never met a
  processor that made it true.
- ADR-0076's longest-prefix rule, where FPC consumes the point and then fails
  with its own runtime error.

**What this does not buy.** It cannot reach `tests/dialect/` and never will:
nobody else implements this language, which is [§1](../roadmap.md) and not
something a gate discharges. It reaches 103 of 244 cases with a golden; FPC
refuses 141, modules above all. And it is pinned to **one version** of one
processor — the catalogue names Free Pascal 3.2.2 and a new FPC will move
entries, which is a maintenance cost accepted deliberately, because an entry
that moves is an entry somebody has to re-judge and that is the gate working.

**The corpus that could not be reached is the honest headline.** 141 refusals
against 105 comparisons is a fact about how far this language has already
gone, and it will only grow. The roadmap's sentence stands and now has a
number behind it: this was worth doing now and will be worth less every
release.

## Alternatives considered

**A one-off measurement, reported and not committed.** It is what the work
started as. Rejected on the register's own rule — a finding recorded and left
is a finding wasted — and on the sharper one: an uncommitted measurement is a
claim nothing checks, and `doc/sop.md` §7 exists because this project has been
green over exactly that shape before.

**A gate with no catalogue, requiring every case to agree.** Impossible and
wrong: 26 of the disagreements are this compiler being *stricter* than FPC,
and making them pass would mean giving up ADR-0014's error detection.

**Normalising the trap cases away by comparing only the golden's prefix.**
This is what the harness does, and the alternative was to catalogue each — 26
entries repeating one sentence. The class is the fact.

**p5, or another ISO 7185 implementation.** p5 needs an existing Pascal
compiler to bootstrap, so it arrives through FPC anyway. Worth revisiting only
if FPC's refusals turn out to hide something.
