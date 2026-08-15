# 101. What an independent reading found

Date: 2026-08-15

## Status

Accepted.

## Context

ADR-0089 to ADR-0100 settled twenty-nine conformance questions in one sweep,
and every one of them turned on a reading of a clause. ADR-0085 had already
given up the only oracle that could disagree with a reading — two independent
implementations — so what was left all descends from the same source: the
goldens were written from this compiler's output, and the BSI catalogue rows
were edited to match it.

So the sweep was audited by three readers told to **prove the compiler wrong**,
working from the standards and compiled probes, with the records and the
project's own documentation withheld. They were pointed at the eleven decisions
with the most judgement in them and asked for programs now *wrongly refused* —
over-strictness being the direction a user cannot work around.

## Decision

**All eleven readings stand.** No over-strict case was found in any of them,
across roughly 240 probe programs and a recompilation of all 231 CONFORM
programs in the BSI suite, of which exactly one is refused and for an unrelated,
documented reason.

Two are worth recording because they were the ones most likely to be wrong:

- **§6.4.3.3's variant coverage** — the reading that refuses `case tag: integer
  of 1: …; 2: …` because `integer` has other values. BSI's own DEV073 header
  settles it: *"Test reclassified from CONFORMANCE to DEVIANCE due to change in
  DP7185"*. The permissive reading was pre-standard behaviour and the standard
  changed it. Annex D lists no entry for §6.4.3.3, so it is not an error a
  processor may leave undetected; §5.1 e) then requires it to be reported.
- **§6.6.3.3's packed rule** as the immediate container rather than the whole
  designator — settled twice over, by "the type that variable *possesses*" and
  independently by §6.4.3.1's statement that packing does not propagate inward.

**Three under-strict defects were found and are fixed here.**

1. **A required function was resolved by spelling.** `LookupBuiltin` runs when
   a name does not resolve to something invocable — so a program declaring
   `var ord: array [1..3] of integer` still had `ord('a')` mean the required
   function, and one identifier denoted two things in one block. §6.2.2.11
   forbids exactly that. The required *procedures* never had it: their path has
   no such fallback. §6.2.2.10 names "procedures, and functions" in one
   sentence, so the asymmetry was never licensed.

2. **A goto could enter a case-statement-completer.** ISO/IEC 10206:1991
   §6.9.3.5 spells it `otherwise statement-sequence`, making it the third
   statement-sequence in the language — and the only one with no node of its
   own, its statements hanging off the case statement. ADR-0094's rule asked
   the *node's kind*, so it could not see one, and a label inside a completer
   read as though it sat at the case statement's level. `stmtPathRec` carries
   the answer now instead of deriving it.

3. **§6.7.3.3 has three closing sentences and two were implemented.** The third
   forbids an actual variable parameter denoting a component of a **string-type**.
   ISO 7185 needs no such sentence, every string-type there being a packed array
   of char; what it adds is the *variable*-string, and `p(s[2])` compiled and
   mutated the string through the reference.

## Consequences

**472 cases pass.** Each fix is pinned by a mutation that a named test kills.

**The audit's value was in the confirmations, not the fixes.** Three defects in
a sweep of twenty-nine is a good rate, but the finding that matters is that the
readings held — including the one that had broken three programs in this tree
and been "fixed" by editing them, which is the pattern that should always draw
suspicion.

**One reader disclosed that the project's own guidance had been injected into
its context automatically**, defeating the isolation it was asked to keep. It
compensated by deriving every verdict from quoted clause text and probes. Worth
recording: an audit's independence is a property of the harness, not of the
instruction, and this one could not be fully guaranteed.

### What this does not do

**§6.4.3.3's record region is still enforced only for a pointer domain.** A
field-identifier shadowing a type-identifier is not detected where the applied
occurrence is an ordinary field's type or an array's index-type — `record a:
fred; fred: integer end` is accepted. The same clause and the same region; only
the occurrence differs. It needs a deliberately perverse program to reach and is
recorded rather than fixed.

**§6.8.3.9's threat rule outlaws a common idiom, and correctly.** A global used
as a loop control variable, where *any* procedure in the block also assigns it,
is now refused — the clause names the procedure-and-function-declaration-part
explicitly and says nothing about whether the procedure is ever called. This
will reject previously-working code. There is no room in the wording to relax
it, so it belongs in the release notes rather than in the compiler.
