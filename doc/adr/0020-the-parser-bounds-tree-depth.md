# 20. The parser bounds tree depth, for every walker at once

Date: 2026-08-09

## Status

Accepted

## Context

The parser is recursive descent, and recursion depth is input-controlled: a
factor may be a parenthesised expression, a statement may contain statements, an
array's component may be an array. With no bound, pathological input runs the
stack into the guard page and the compiler dies with SIGSEGV instead of a
diagnostic. Measured on an 8 MiB stack, nested parentheses killed the parser at
about 19 000 levels.

The subtler half of the problem is that the parser is not the only recursive
walk, and not always the first to die. `a+b+c+...` is parsed by an *iterative*
loop — the parser's stack never grows — but the loop builds a left-leaning tree
as deep as the chain is long, and Sema recurses down it: a 31 000-term chain
segfaulted in `Sema::checkBinary` after parsing without incident. CodeGen walks
the same tree, and so does the AST's own destructor, whose `unique_ptr` chain
runs even when compilation fails. A bound on the parser's *call depth* would
have missed all three, because the dangerous quantity is the depth of the tree
handed onward, not the depth of the recursion that built it.

Every recursion-proofing alternative was considered against the bootstrap:
converting four tree walks to explicit-stack iteration contorts exactly the
code that is headed for a Pascal rewrite, and growing the stack merely moves
the number.

## Decision

**The parser enforces one limit on the depth of the tree it builds — 1000
levels — and everything downstream inherits the bound.**

A member counter tracks the depth of the node currently under construction.
Recursive productions hold an RAII guard that counts one level; the three
spine-building loops — the operator loops in `parseSimpleExpr` and `parseTerm`,
and the selector loop — count one level per *iteration*, which is what makes
the limit a bound on the tree rather than on the parser's own stack. In the
expression grammar only `parseFactor` charges for entry, because every way an
expression nests passes through it exactly once per level; the loop hosts hold
a free guard that counts only its bumps. Exceeding the limit is an ordinary
diagnostic ("nesting is too deep") through `Diagnostics` followed by
`ParseAbort`, like any other parse error.

The number 1000 is not delicate. The tightest measured walker fails beyond
19 000 tree levels; the limit leaves better than an order of magnitude of
headroom for the parser, Sema, CodeGen and the destructor on every input shape
tried — parentheses, operator chains, `not` chains, `begin`/`end` nesting,
selector chains, and `array of array of ...` type denoters, each of which now
gets the diagnostic at 998 or 999 accepted levels.

## Consequences

The compiler now refuses a class of programs ISO 7185 does not forbid. That is
an implementation limit, and it is documented as one; clang's default bracket
depth of 256 is precedent that a fixed, stated limit is the normal engineering
answer. No human-written program is within two orders of magnitude of it.

The refusal can matter for *machine-generated* Pascal — a constant chain of a
few thousand terms is legal, flat for the parser, and dangerous only to the
recursive walkers. If a real generator ever hits the limit, the alternative for
chains specifically is to iterate the left spine in Sema, CodeGen and the
destructor; that is deliberately not being done now, because it buys capacity
nobody has asked for at the price of contorting three walks that must stay
portable to Pascal.

The guard-plus-counter shape is itself bootstrap-friendly: a counter, a
comparison and an error call translate to Pascal verbatim, where an
explicit-stack traversal would not. The one piece that does not port is the
RAII decrement, which in Pascal becomes an explicit decrement at each
production's exits — a known cost, noted here so the port does not rediscover
it.

`tests/deep_nesting.pas` pins the recursion path (1500 parentheses) and
`tests/deep_chain.pas` pins the spine path (a 1500-term chain); the second is
the regression test for the mistake this record exists to prevent, a depth
limit that counts only calls.
