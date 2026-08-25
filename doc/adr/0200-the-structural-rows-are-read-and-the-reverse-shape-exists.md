# 200. The structural rows are read, and the reverse shape exists

Date: 2026-08-25

## Status

Accepted. The `structural` half of `tests/spec/clauses/triage.tsv`, swept
against the standards.

## Context

ADR-0106 made the clause denominator a triage: `testable`, `structural`,
`not-implemented`, with only the first entering the coverage figure and the
work queue. A requirement filed `structural` therefore disappears completely —
it is in no percentage, in no `pending.txt`, and nothing ever asks for it
again.

An earlier audit read about twenty of those rows by hand and found four wrong,
two of them sharing one copied reason string. `doc/sop.md` §7 has carried the
rest as unaudited since. ADR-0197's sweep of that register was what brought the
row back into view.

## Decision

**Every structural row is read against its own clause text**, and the reading
is mechanical enough to be worth describing: `pdftotext -layout` over the two
vendored standards, a heading index, and the body of each clause from its
heading to the next. 82 rows in the two standards and 49 in the dialect
specification.

**The signal is `shall` in the clause's own prose** — excluding NOTEs, which
are informative, and excluding the standard's own examples. Eleven of the 82
rows have it, and every one was read in full.

## Consequences

**Four rows were misfiled, and one of them is the clause that says what
conformance *is*.**

- **ISO 7185 5.1 and ISO/IEC 10206:1991 5.1, Processors** → `testable`. The
  reason read *states what a processor or a program is, not what either does*,
  and 5.1 is six lettered requirements about what a processor does. Two are the
  general rule behind everything this compiler reports: e) a violation that is
  not an error shall be reported **before** the program-block is executed and
  execution then prevented, and f) an error shall be treated in one of three
  ways. Neither is stated in any other clause — §6.4.6 says what
  assignment-compatibility is, and 5.1 e) is why a program that lacks it does
  not run.
- **ISO 7185 6.2.3.3** → `testable`, and it is **the reverse of the shape the
  earlier audit found**. That audit's rule of thumb was *an Extended Pascal
  clause that gained a sentence the ISO 7185 clause of the same number does not
  have*; here ISO 7185 has a last paragraph that ISO/IEC 10206:1991's clause of
  the same number does not — within an activation, an applied occurrence
  denotes *that activation's* entity, except that a function-identifier in an
  assignment-statement denotes the result. Extended Pascal states both at
  §6.7.2 and §6.9.2.2 instead. So the shape is not one standard gaining
  sentences; it is that two documents of the same shape distribute one rule
  differently, and a triage row copied across both is wrong on one side.
- **AP 6.4.6** → `testable`. Its reason described its first sentence, a
  cross-reference; its second is a prohibition of its own — no value is
  assignment-compatible with a slice and a slice with no type — which ADR-0143's
  defect violated, copying one array's contents over another's and exiting 0.

**Nine reasons were corrected with the class left alone**, all of them saying
"states no requirement of its own" about a clause that states one:

- the four *General* clauses of the required procedures and functions, which
  classify them into the categories their subclauses then enumerate;
- the two *Repetitive-statements* clauses, a container production plus one
  sentence each subclause states precisely;
- Extended Pascal 6.11.4.1, which introduces the required interfaces;
- both 5.2 *Programs*, which require of a **program** and not of a processor —
  a conformance level, and not relying on an implementation-dependent
  interpretation. What a processor must do about a program that fails this is
  5.1 e), which is why the two clauses are not the same question.

**Five scenarios.** Clause 5.1 gets two per standard — a violation reported and
the program not run, an error reported and the program stopped — and 6.2.3.3
gets a recursive factorial, which needs both halves of its paragraph at once:
`fact := n * fact(n - 1)` is an assignment to the result on the left and a call
on the right, and each activation's `n` must be its own for the answer to come
out. AP 6.4.6 gets two, one per direction of the prohibition.

**The denominator moved** from 98 to 100 testable in ISO 7185, 147 to 148 in
Extended Pascal and 89 to 90 in the dialect specification, and every clause
reclassified is cited, so `pending.txt` is unchanged.

## What this does not do

**It does not audit the `testable` rows**, and that is now §7's row in place of
this one. A clause filed `testable` that states no requirement sits in
`pending.txt` for ever as work nobody can do — the mirror failure, and about
350 rows wide. It is a much weaker signal: "states a requirement" cannot be
read off the presence of `shall`, and most of those rows carry a reason that is
only the clause's title, which is not an argument.

**It does not check that a `testable` row's clause is implemented.** That is
what `not-implemented` is for and there are none.

**The method confirms a row it cannot read**, which is the thing worth carrying
away. Twelve of the 82 structural clauses are ADR-0152's bare-numbered ones —
§6.2.2 and §6.2.3 in both standards, a number alone on a line with the
requirement under it — and the heading index did not find them, so the first
pass returned an empty body for each and every one read as *states nothing*,
which is exactly what its row claimed. It was caught only because the extractor
was asked how many headings it had failed to locate. A sweep that cannot
distinguish "there is nothing there" from "I could not look" agrees with
whatever it is checking; ISO 7185 6.2.3.3, one of the four findings, is in that
twelve.

## Alternatives rejected

**Reading the rows without the standards.** The triage is a reading and the
clause text is the only thing that can contradict it — which is
`.claude/skills/langspec-audit/`'s premise. Judging a row from its own reason
is how a copied reason survives 51 times.

**Filing 5.1 as `not-implemented` for its level-0 clause.** This is a level 1
processor (ADR-0153), so a) is satisfied by b); nothing of 5.1 is unimplemented.

**Leaving the nine reasons alone because the class was right.** The class being
right is what makes the reason dangerous: it reads as though someone checked,
and the next reader has no way to tell a reason that was verified from one that
was copied. Two of the earlier audit's four findings came out of exactly that
string.

**Making the four *General* clauses testable too.** They state a `shall`, and
what it requires is discharged entirely by the subclauses that enumerate the
members — so a scenario citing one would be filing a citation under a
requirement it does not check, which is the failure `spec-clause-traceability`
exists to make visible.
