# 92. Three rules about a parameter list

Date: 2026-08-15

## Status

Accepted.

## Context

Three clauses about parameters, each documented as a known gap and each with a
BSI program and none in this tree.

## Decision

**§6.6.3.2 — a value parameter's type shall not contain a file.** "The type
possessed by the formal-parameter shall be one that is permitted as the
component-type of a file-type." `ContainsFile` *is* that predicate — the same
one `CheckedResultType` asks of a function result and `ResolveFile` asks of a
component — so the check was `IsFile` where it should have been `ContainsFile`,
and a record or array holding a file was copied. One word, plus a second
message arm so the bare-file wording is unchanged.

The clause is **§6.6.3.2, not §6.6.3.3**; the comment in the compiler cited the
variable-parameter clause, which says nothing about files.

**§6.6.3.3 — an actual var parameter may not be written `(variable)`.** §6.5.1's
four variable-accesses do not include a parenthesised expression. **The parser
had dropped the brackets**: `(a + b) * c` is the node `a + b` is, so `p((x))`
and `p(x)` produced identical trees and nothing downstream could tell them
apart. The node carries one boolean now, set in the one place the parser
consumes a bracketed expression, and the argument check is the only reader.

**§6.6.3.6 — congruity is over *sections*, not parameters.** "Two
formal-parameter-lists shall be congruous if they contain the same number of
formal-parameter-sections and if the formal-parameter-sections in corresponding
positions match", and b) adds "containing the same number of parameters". So
`(var a, b: integer)` is one section of two names and `(var a: integer; var b:
integer)` is two sections of one, and they are not congruous however alike their
parameters are. ADR-0030's summary — "same count, same passing mode, same type"
— describes what was implemented and is an incomplete description of the clause.

`Symbol::paramSection` already existed and `BuildFormals` already numbered
sections; the number was simply never **assigned to a procedural parameter**,
which kept `NewSymbol`'s zero and misnumbered every section after one. Given the
parameter counts already agree, equal section numbers at every position is
exactly the clause — the boundaries can line up only one way.

## Consequences

**459 cases pass and the compiler still compiles itself.** It declares no
procedural parameters at all and passes no parenthesised actual, so two of the
three could not have reached it; the file rule could, and the only type in this
tree that contains-but-is-not a file is never a parameter.

**`nParen` is the second time the parser has been asked to remember something
it had correctly thrown away**, after ADR-0066's `SubstringExpr::listed`. Both
are one boolean on a node, read in exactly one place, because the alternative —
a wrapper node — makes every consumer see through it.

**Two goldens gained one line each**, and the message-text diff was checked with
the line numbers stripped, so what moved is the two new diagnostics and not a
reordering.

### What this does not do

**It does not extend the parenthesis rule past a var parameter.** §6.5.1
equally forbids `read((x))`, `new((p))` and `pack((a), i, b)`, all of which are
accepted today and none of which BSI's program reaches. Folding the test into
`IsDesignator` would close them together and was measured as safe on this
corpus — but that predicate answers §6.5.1's question for a dozen constructs
that have other reasons to be designators, and widening it here would grant the
rule to callers this clause says nothing about. That is ADR-0058's lesson about
a permission granted in a shared predicate, run in the other direction.

**It does not check the other two restrictions on an actual var parameter** —
a component of a packed variable, and a variant part's tag-field. Both remain in
`doc/implementation-defined.md`.
