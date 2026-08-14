# 89. A `for` control-variable may not be threatened

Date: 2026-08-15

## Status

Accepted. Retires the deferral recorded in ADR-0063.

## Context

ISO 7185 §6.8.3.9:

> Neither a for-statement nor any procedure-and-function-declaration-part of
> the block that closest-contains a for-statement shall contain a statement
> threatening the variable denoted by the control-variable of the
> for-statement.

ISO/IEC 10206:1991 §6.9.3.9.1 is the same sentence with a cross-reference to
§6.9.4 spliced into it, and §6.9.4 is the list of what *threatens* a variable —
an assignment, an actual variable parameter, a `read`, a nested `for` over the
same variable.

**None of it was enforced.** ADR-0063 stated the gap plainly while landing the
set-member form: "`checkNotThreatened` fires only for protected symbols, so the
rule is written down in §6.9.4 and nowhere in this compiler. The set form
inherits that gap rather than creating it." Five of the BSI suite's DEVIANCE
programs are that shape — one per threat, plus DEV224 — and they were the
largest single group left in `doc/implementation-defined.md` §6.1.

## Decision

**The threat list already existed; it was asking the wrong question.**
ADR-0046 implemented §6.9.4 for Extended Pascal's `protected` parameters, and
its argument was that "every entry on §6.9.4's list of threats is a place this
compiler had already decided the argument was a variable, so each check sits
beside an existing `isDesignator` test." Those call sites are the whole of what
this rule needed: `Threatened` gained a second reason to answer yes, and the
four sites an ordinal entire-variable can reach — assignment, actual var
parameter, `read`, and the new nested-`for` test — needed nothing.

- `forTop` is the stack of control variables whose **bodies** are being walked.
  The bounds are expressions and the clause names a *statement*, so the binding
  covers the body and nothing else.
- **Keyed on the symbol, never on the spelling.** A procedure's own local `i`
  is not the `i` an enclosing block loops over; the suite has twenty programs
  that differ in exactly that way, and a spelling-keyed check reports every one.
- **The message is composed, not duplicated.** `Threatened` writes the opening
  and the caller writes the tail it already wrote, so one rule keeps one wording
  across four places and the new reason reads *"'i' is the control variable of a
  for statement, so it cannot be read into"*.

**DEV224's half is a *record*, not a search.** The clause reaches the
declaration part of the containing block, where the threat may be in a
procedure that is never called — BSI puts it behind `if 1 = 0` precisely so no
optimiser can remove it. That needs no whole-program analysis, because
`CheckBlock` already walks every nested body *before* the statement part that
loops: a threat made from a nested block is stamped on the symbol when it is
seen, and the for-statement asks afterwards.

**The threat questions are asked only of something that can be a
control-variable.** Anything ADR-0077's rule refused has been reported already,
and asking further questions of it reports a consequence of the first fault
rather than a second one (ADR-0054's principle).

## Consequences

**Five programs now refused**, and 450 cases pass — the compiler still compiles
its own 24,600 lines, which is where a false positive would show first.

**The guard against asking twice was found by a golden, not by reasoning.**
Without it the nested-`for` test calls `Threatened` on the control variable,
which *records* a threat against it — so a loop over an enclosing block's
variable reported itself, naming its own line as the threat.
`tests/forvar_errors.err` went red and said so. The lesson is ADR-0088's from
the other side: a check that both writes and reads one piece of state has to
say which order it does them in.

**One golden gained a line, and it is a real detection.**
`selfhost/badsema/statements.pas:11` is `for i := true to 2 do i := 1` — a body
assigning to its own control variable, unreported since the file was written.

**The diagnostic for DEV224's shape points at the loop, not at the threat**, and
names the threat's line in its text. That is unavoidable: the statement in the
declaration part is legal until a later for-statement makes it not, so the
position a reader needs is the one the compiler cannot report at.

### What this does not do

**It does not make the control-variable undefined after the loop**, which
§6.8.3.9 also requires and ADR-0063 also deferred. That is a definedness
property, and it belongs with the eight Annex D entries
`doc/implementation-defined.md` already groups under "nothing here tracks
definedness at run time" rather than with this rule.

**It does not enforce the rule for labels**, there being none to enforce — the
clause is about variables.

**The `NestedIn` guard on recording a threat is unreachable, and is kept
anyway.** It asks that the threatening block lie in the declaration part of the
variable's owner, which excludes an imported module variable (ADR-0053), whose
symbol is a copy sharing an owner in another tree. No test reaches it, because
ADR-0077 already refuses an imported variable as a control-variable, so the
recorded threat could never be consulted. It states the clause's own words
where a reader will look for them; removing it survives every oracle here, and
that is not licence to remove it.
