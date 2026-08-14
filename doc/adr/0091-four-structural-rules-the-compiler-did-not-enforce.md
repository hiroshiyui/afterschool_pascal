# 91. Four structural rules the compiler did not enforce

Date: 2026-08-15

## Status

Accepted.

## Context

Four unrelated clauses, batched because each is too small to be a record of its
own and they share nothing but the sweep that found them (ADR-0086's corpus).
Each was written down as a known gap in `doc/implementation-defined.md`; none
had a program in this tree.

## Decision

**§6.4.4 — a pointer's domain-type shall be declared.** `ResolvePendingPointers`
always had the diagnostic; it was never *called* for a domain written outside a
type-definition-part. The drain fired only when a run of type definitions
ended, so a program with no type part kept its unknown domain in silence. It is
now unconditional.

**§6.1.8 / §6.1.10 — a separator between a number and what follows.** "There
shall be at least one separator between any pair of consecutive tokens made up
of identifiers, word-symbols, labels or unsigned-numbers." One test in the
lexer's decimal branch. Only the decimal form needs it: an extended-digit
sequence is maximal and a letter *is* a digit there (ADR-0036), so nothing but
a non-letter can follow one.

**§6.6.1 — `forward` follows a heading, not a procedure-identification.** The
compiler already recognised the resumption exactly — that is what its
"parameters were already given" check is about — and simply never looked at the
directive.

**§6.5.4 — a function-identifier is not a pointer-variable.** ADR-0056 gates
Extended Pascal's function-access in the *parser*, which works only because a
call written **with arguments** is what makes the parser build a call node. A
parameterless function is a bare identifier, indistinguishable from a variable
until Sema resolves it — so the parser's gate cannot reach this shape, and Sema
is where it is told.

## Consequences

**458 cases pass and the compiler still compiles itself**, which mattered most
for the lexer change: a rule about what may follow a digit is applied to 24,600
lines of Pascal on every build.

**The §6.4.4 fix was worth more than the program that found it.** Draining only
after a type part carried the pending list into the *next* block that happened
to have one, where the name was looked up in the wrong scope. Two consequences
neither the suite nor this tree had a program for:

- an unknown domain in a program with no type part was accepted **silently**,
  and the same program with an unrelated procedure after it reported the error
  against that procedure;
- a **legal** Extended Pascal program was refused — a schema naming itself in a
  pointer domain (§6.4.7's one permitted self-reference) used by a *variable*
  declaration pended forever, and `new` then reported that it needed a pointer
  variable. Adding an unrelated type definition after the var part made the
  identical program compile, which is what identified the drain rather than the
  schema as the fault. `tests/extended/schema_selfpointer_var.pas` is that
  program and is the more valuable of the two tests.

**Four claims left `doc/implementation-defined.md`.** One of them had been
describing the §6.4.4 gap as living in §6.2.2.9's exception, which is where the
*neighbouring* CONF027 behaviour lives and not where this one did.

### What this does not do

**It does not report which token the run-together number was meant to be.** The
message names the rule; `10div` could be `10 div` or a mistyped identifier, and
the lexer is not the place to guess.

**§6.5.4's check does not reach a function-*designator* with arguments under
ISO 7185**, because ADR-0056's parser gate already refuses that with a
different message — one about the selector, not about the rule. Two diagnostics
for two shapes of one clause, which is the cost of gating in two places; the
parser's cannot be moved without giving Extended Pascal's function-access a
different grammar.
