# 77. Annex D is a checklist

Date: 2026-08-13

## Status

Accepted.

## Context

ADR-0071 put a compiled program against each of Annex A's 274 productions and
found six things wrong. ADR-0076 did the same for the forms that sweep had left
unexercised. The method is the same each time and so is the finding: a bounded
list the standard itself provides, a probe per entry, and a construct no
program in the corpus had ever written — so all five oracles agreed with a
compiler that was wrong.

Annex D is another such list. It enumerates all sixty errors clause 6 defines,
"to facilitate the production of" the documentation clause 5.1 f) requires of a
processor's treatment of them. `doc/implementation-defined.md` has a section
for the ones this processor leaves unreported, written from the architecture
decision records rather than from the annex — which is the gap: a record can
only mention an error someone thought about.

## Decision

**Six of Annex D's errors are reported that were not.**

| | The error | was |
|---|---|---|
| D.33 | `ln(x)`, x not greater than zero | −∞ |
| D.34 | `sqrt(x)`, x negative | NaN |
| D.44 | `x/y`, y zero, real | ∞ |
| D.44 | the same, complex (§6.8.3.2 table 3) | NaN |
| D.46 | `i mod j`, j **negative** | a number |
| D.23 | `dispose(p)`, p nil | nothing |

Each is one comparison against zero on a value the lowering already had. None
was in the unreported list, so all six were undocumented as well as unchecked,
against a README that has said "ISO error conditions trap" since ADR-0014.

**And §6.8.3.9's control variable belongs to its own block.** "The
control-variable shall be an entire-variable whose identifier is declared in
the variable-declaration-part of the block closest-containing the
for-statement" — a *shall*, so a violation must be reported rather than being
an error a processor may leave. Only the "is a variable" half was checked, so a
procedure looping over the program's `i` compiled and printed the right
numbers.

## Consequences

**`mod` is where the compiler disagreed with itself, which is the sharpest
form this shape takes.** §6.7.2.2 makes a divisor that is zero *or negative* an
error. Sema's folder has always refused a constant one, with the message "the
right operand of mod must be positive" and a comment saying the emitted code
follows the same rule "so a folded `mod` and a computed one cannot disagree".
They could: `const c = 5 mod -3` was a diagnostic and `j := -3; i := 5 mod j`
computed 1. The run-time check now uses the folder's words, which is what makes
one rule one answer — and it is ADR-0054's own requirement, written down and
then not held to.

**`dispose` of nil was checked where it was *harmful*, not where it was
wrong.** ADR-0043 added the check for a schema domain, because stepping back
over a tuple header turns disposing nil into a free of an address that was
never allocated. Everywhere else `free(nil)` does nothing, so the error was
harmless — and harmless is not the test §6.6.5.3 sets. It is the same
comparison either way; what differed was the reason to report it, never the
rule. CLAUDE.md had recorded the asymmetry deliberately, which is how a
decision about a hazard came to read as a decision about the standard.

**The complex division's comment named a reason that stopped being true.** It
said trapping there "would be the odd one out", real `/` not trapping either.
Now that one does, so this arm follows rather than staying behind. The divisor
is zero exactly when c² + d² is, and that number is already being computed for
the quotient — one comparison rather than two.

**`verify/` gains no rule, and the reason is the useful part.** Each check's
ISO condition *is* the emitted test — "an error if y is zero" lowered as
`y == 0` — so a rule would restate the lowering, which CLAUDE.md forbids and
the nil check is the standing precedent for. What did change is `lowering.py`'s
model of `mod`, which now records that the guard turns `rules.py`'s `j > 0`
precondition from an assumption into something the compiler enforces. The
precondition was always right; until the guard existed the proofs simply said
nothing about the values the compiler was quietly computing outside it.

**The `for` message named the wrong thing.** A parameter used to be told "the
control variable of a for statement must be a variable" — and a value parameter
*is* a variable. The complaint was never about what it is but about where it
was declared, and the message says that now, which is accurate for a parameter,
a constant, an imported name and an enclosing block's variable alike. ADR-0074
found the same fault in a different message; this is the second time a
diagnostic has been correct about the outcome and wrong about the rule.

**Nothing in the corpus was affected — including the compiler's own source.**
`selfhost/compiler.pas` has 274 `for` statements and every one obeys §6.8.3.9
already; no program divided by a zero it did not write as a literal, took
`sqrt` of a negative, or used `mod` with a negative divisor. Enforcing all
seven rules changed exactly one existing expectation, and it was a message.

### What this does not do

**It does not report the errors that need run-time bookkeeping.** D.20 to D.22
want the pointer's *value* to carry which form of `new` created the variable,
which is D.25's cause and already recorded; D.4, D.24 and D.43 want definedness
tracked. Both are now rows in the unreported table rather than being left to be
inferred from the entries that share their cause — Annex D names the undefined
case three times, and a reader should not have to work out that one sentence
covers all three.

**It does not check real overflow.** D.32 and D.47 make a value the type cannot
represent an error, and an operation on reals that overflows still yields an
infinity here. That is a different mechanism from a comparison against zero — it
would need every real operation guarded — and it is the one entry from this
sweep left open rather than answered.
