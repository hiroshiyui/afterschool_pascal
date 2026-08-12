# 63. A set-member-iteration is a walk over the bits

Date: 2026-08-12

## Status

Accepted.

## Context

ISO/IEC 10206:1991 §6.9.3.9.1 restructures the for-statement:

>     for-statement = 'for' control-variable iteration-clause 'do' statement .
>     control-variable = entire-variable .
>     iteration-clause = sequence-iteration | set-member-iteration .
>     sequence-iteration = ':=' initial-value ( 'to' | 'downto' ) final-value .
>     set-member-iteration = 'in' set-expression .

The `:=` moved out of the for-statement and into one of two alternatives. The
new one, §6.9.3.9.3:

> The set-expression ... shall possess an unpacked-canonical-set-of-T-type or a
> packed-canonical-set-of-T-type. The type of the control-variable ... shall be
> compatible with T. The set-expression shall be evaluated prior to the first
> execution, if any, of the statement ... For each member of the value of the
> set-expression, the value that is the member shall be attributed to the
> control-variable, and then the statement ... shall be executed. **The order in
> which members of the value of the set-expression are selected shall be
> implementation-dependent.**

## Decision

**A set is one 256-bit word with a bit per possible member (ADR-0028), so "for
each member" is a walk over the base type's ordinals testing one bit.** The
loop counter is an `i32` of its own and the test is the `lshr`/`and`/`icmp ne`
that the `in` operator already emits — with the member arriving as the
counter rather than as an expression.

That is the whole lowering, and three of the four things it needs were decided
elsewhere:

- **"Evaluated prior to the first execution" is free.** A set is a *value*, so
  emitting the set-expression before the loop *is* evaluating it once; nothing
  in the body can reach the storage it came from. `tests/extended/setiter.pas`
  assigns to the set variable inside the loop and iterates the old value, and
  there is no `alloca` making that true.
- **D.96 is the store's existing check.** §6.9.3.9.3 makes the *members*
  assignment-compatible rather than the set, so a control variable narrower
  than the base type is legal and a member outside it is an error. That is
  `checkedForSubrange`, called where the member is attributed —
  `tests/extended/trap_setiter.pas` is `for c in ['a', 'z']` with `c` a
  `'a'..'e'`.
- **The counter cannot overflow.** The sequence form tests `= limit` before
  stepping because its last iteration otherwise would (ADR-0014, and `verify/`
  carries the theorem). Here the counter is an `i32` bounded by 255, so the
  care is unnecessary rather than omitted — and `verify/` gained nothing,
  because there is no new arithmetic to prove anything about.

**The order is ascending, and that is a documented choice rather than a
requirement**: §6.9.3.9.3 says implementation-dependent, and ascending is what
a walk over the bits gives.

**The two forms are one node with two shapes**, because §6.9.3.9.1 makes them
one production with two alternatives. `ForStmt::set` non-null is the set form,
and then `from` and `to` are null. The AST dump's head says which — `for in`
beside `for to` and `for downto` — which is the only place the choice is
visible to `difftest`.

**It reserves nothing.** `in` is an ISO 7185 word-symbol already, so the
feature costs that language no identifier — the second such after `and then`
(ADR-0038) and `type of` (ADR-0047). One token of lookahead after the
control-variable separates the two clauses, and the ISO 7185 gate is a parse
error: `tests/setiter_iso.pas`.

## Consequences

**The iteration range is clamped to 0..255, and finding out why is the whole of
what this feature taught.** The base type of a set *constructor* is inferred
from its members, so `[1, 2]` is a set of `integer` — a type ADR-0028 refuses
to *declare* but happily infers — and asking that type for its ordinal range
gives −maxint..maxint. The first run of `for i in [1, 2]` scanned two billion
values. There is no bit outside 0..255 for a member to be in, so the clamp is
not a guard against the inference: it is the truthful statement of where a set
keeps its members.

**A nested set-iteration needs distinct control variables**, and that is
§6.9.4 g) rather than anything new — a for-statement threatens its own control
variable, exactly as the sequence form's does.

**Every restriction on the control-variable was already checked**, because
§6.9.3.9.1 sits above the split: entire-variable, declared in this block, an
ordinal type, not a field of an enclosing `with`. `tests/extended/setiter_errors.pas`
reaches each of them through the new form, and the messages are the ones the
sequence form has always produced.

### What this does not do

**§6.9.4 g) is still not enforced**, for either form: a body that assigns to
the control variable is accepted. `checkNotThreatened` fires only for protected
symbols, so the rule is written down in §6.9.4 and nowhere in this compiler.
The set form inherits that gap rather than creating it, and it is worth naming
here because a set-iteration makes the consequence stranger — assigning to the
control variable does not perturb the iteration at all, since the counter is a
separate hidden variable.

**"After a for-statement is executed the control-variable shall be undefined"
is not modelled**, in either form. The variable keeps the last value it took,
which a conforming program cannot observe and a non-conforming one can.

**A `packed` set is not distinguished from an unpacked one**, because this
compiler has one set representation; §6.9.3.9.3 admits either and they are the
same type here.
