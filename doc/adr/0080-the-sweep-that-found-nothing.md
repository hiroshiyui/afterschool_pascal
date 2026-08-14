# 80. The sweep that found nothing

Date: 2026-08-14

## Status

Accepted.

## Context

ADR-0079 closed the last clause of ISO/IEC 10206:1991, and `doc/roadmap.md`
then said no production, required identifier, required type, lexical rule or
clause was outstanding. Four of those five were backed by a sweep — Annex A's
productions forwards (ADR-0071) and backwards (ADR-0072), Annexes E and F
(ADR-0073, ADR-0074), and both Annex Ds (ADR-0077, ADR-0078).

**"Required identifier" and "required type" were backed by nothing but a
reading**, which is the shape ADR-0067 warns about. It is also the exact list
that failed here before: §6.6.5.4's `pack` and `unpack` and §6.9.5's `page`
were missing while three documents asserted ISO 7185 was complete, because the
names were in `isRequiredName` — so §6.6.3.7 could refuse passing one as a
parameter — and were nowhere else. The tag `iso-7185-done` had already been
moved when §6.3's string constant was found the same way hours later
(ADR-0068).

A tag is a durable public claim, so the sweep ran before `iso-10206-1991-done`
rather than after.

## Decision

**Annex C is the checklist**, and it is the standard's own enumeration:
94 required identifiers, each with the clause that defines it. Every one was
probed with a program that **uses it for its purpose**, compiled and run, and
whose answer was checked.

**All 94 pass**, and the answers are right where a wrong implementation would
still compile: `index('abcdef', 'cd')` is 3, a `string(10)`'s `capacity` is 10,
`date(t)` is ten characters and `time(t)` eight, `succ(4, 3)` is 7 and
`pred(9, 3)` is 6. The three required *directives* — `forward`, `interface`,
`implementation` — were probed too and work; they are correctly absent from
Annex C, §6.1.5 and §6.1.6 making them directives rather than identifiers,
which is ADR-0053's "five word-symbols, not seven".

**Annex C is informative, so it was cross-checked against the normative text.**
Every name clause 6 calls required — `GetTimeStamp`, `bind`, `dispose`, `eof`,
`extend`, `new`, `pack`, `read`, `readln`, `readstr`, `reset`, `string`,
`text`, `writeln`, `writestr` — is in the list that was probed.

`tests/extended/required_identifiers.pas` is what the sweep leaves behind: one
program naming all 94 in executable code, with `.in` for the required
variables and `.epoch` for the required time functions, since a golden file can
only name a date when the clock is fixed (ADR-0065).

## Consequences

**This is the first sweep here to find nothing**, and that is the result rather
than a disappointment. Six sweeps before it each found something, and the
finding always had one shape: a construct no corpus program had written, so
every oracle agreed with a compiler that was wrong. A seventh that comes back
empty is the first evidence that the corpus has caught up with the standard.

**Two probe designs were wrong before the third was right, and the first would
have produced a false all-clear.** It asked whether a name resolves — once in
an expression, once as a procedure-statement — and called a name missing only
when *both* failed. A parse error in the second masked the first, so it
reported all 94 present while `day`, `month`, `bound`, `name` and `capacity`
were plainly undeclared. That is ADR-0034's fault exactly: two rejections
compared, and passing. Asking the expression probe alone then reported 81
missing, because most required identifiers here are recognised **by name**
rather than as symbols in a scope — which CLAUDE.md already records for `read`
and `write`.

Neither question was the right one. **"Is the name in scope" is not what a
required identifier means; "does it do its job" is** — and that is the same
sentence ADR-0067 wrote about `pack`, `unpack` and `page`, whose names *were*
in scope. A sweep can fail in the direction of false confidence, and a sweep
run to justify a tag is exactly where that matters.

**Two more failures were the probes' and not the compiler's**, and both are
worth keeping straight: `pack`'s probe assigned a string literal to an
*unpacked* array, which §6.4.3.2 makes a packed type and the compiler was right
to refuse; and `forward`'s probe recursed past its own `writeln`. A sweep's
own bugs outnumbered the compiler's, four to nothing.

**The test asserts properties where values are not fixed.** `maxreal`,
`minreal` and `epsreal` are checked by §6.4.2.2 b)'s own defining property,
because ADR-0076 found that printed digits pass with any nearby value; the
clock is pinned by an `.epoch` file for the same reason.

### What this does not do

**It does not check the required identifiers of ISO 7185 separately.** All of
them are among the 94 — that standard's required set is a subset — but the
program is Extended Pascal and a few of its lines (`succ` with two arguments,
`string`, `complex`) would not compile under `--std=iso7185`. Nothing here
re-runs the sweep against the older standard, whose own list was closed by
ADR-0067 and ADR-0068.

**It does not enumerate the required *word-symbols*.** §6.1.2's list is
complete and reserved (ADR-0033's caveat expired), and `tests/module_iso.pas`
and `tests/iso_identifiers.pas` pin the ones that cost ISO 7185 nothing; that
is a different list, checked a different way.
