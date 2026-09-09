# ADR-0376: One symbol, one signature

## Status

Accepted. Adds a second claim to `foreign-width` and the catalogue
`tests/checks/foreign_repeats.txt`. Narrows `doc/sop.md` §7's row about
`ExtFd`, and its parent row about an `external` declaration nobody checks.

## Context

`doc/sop.md` §7 has said since ADR-0121 that **nothing checks an `external`
declaration against the function it names**: the call site is the whole of the
ABI, and LLVM does not compare a direct call against its declaration under
opaque pointers, so a wrong arity or type is undefined behaviour with no
diagnostic. ADR-0364 held one property of that boundary — a scalar's *width* —
and ADR-0371 held one function's *arity*.

Investigating the `ExtFd` row turned up a third, and it is the cheapest of the
three to hold: **the same C function is declared in more than one module**, and
nothing compared the declarations. `fclose` is declared nineteen times across
the tree, `fopen` fourteen. Under `lib/` and `lsp/` — `foreign-width`'s own
scope, the corpus holding deliberately-wrong bindings — three symbols repeat.

Two modules disagreeing about what `fopen` returns is exactly the class above,
and it is *checkable* where the rest of that row is not: it needs no header and
no C compiler, only the tree's own declarations.

## Decision

**Every foreign symbol declared more than once under `lib/` and `lsp/` must
have one representation**, or a row in `tests/checks/foreign_repeats.txt`
carrying the argument for why not.

**What is compared is the representation, not the spelling**, and that is the
part that took a false positive to get right. Two modules legitimately name one
C type differently: `PasStream`'s `Stream` and `PasProcess`'s `Pipe` are both
`handle external`, so both are a pointer and the declarations agree without a
row. Comparing the words would report a difference that is not one.

The first version resolved handle types **per file**, and it flagged
`pasx_socket_fd` — the very symbol §7's row was about — because `PasTls`
*imports* `Socket` from `PasNet` rather than declaring it, so the same type
resolved two ways. The false positive looked exactly like the finding. The map
is global now, and `export-unique` (ADR-0298) is what makes that sound: no two
modules export one spelling, so a name means one type across the tree.

One row is needed today. `fflush` takes a `FILE *`; `PasStream` passes a handle
and `PasProcess` passes **null**, which no handle can spell, so it declares the
parameter `csize` — pointer-width by AP 6.4.2.7, which is what ADR-0328 added
for saying "whatever this target's is" without writing a number. It is a row
rather than a blanket rule that a handle and a `csize` are interchangeable,
because they are not: an address carried in an integer is the hazard ADR-0128
refuses, and admitting it everywhere would spend that.

Both directions, as every catalogue here: a disagreement with no row fails, and
a row for a symbol whose declarations now agree fails as well — that is a fix,
and it has to be recorded.

## Consequences

**Three claims are now held about a boundary that had none.** A scalar's width
(ADR-0364), one function's arity (ADR-0371), and one symbol's signature being
one signature. What is still unheld is everything else about every other
declaration — the parent §7 row stays, with three exceptions named instead of
one.

**§7's `ExtFd` row narrows to what it is really about.** The two declarations
of `pasx_socket_fd` are compared now and must agree. What is left is not a
declaration mismatch but a *meaning*: `PasNet` hands the number straight back
to `pasx_socket_poll`, where it need only be a token both ends agree on, while
`PasTls` hands it to OpenSSL's `SSL_set_fd`, where it must be what a foreign
library thinks a socket is. On a platform whose socket is not a descriptor that
second use breaks, and no gate here can see it — but every platform this
project supports is POSIX, and Windows is deferred (ADR-0374), so it is a
port-time concern rather than a live one.

**It is three symbols today**, and the claim is worth having anyway for the
reason every ratchet here is: it is true now, and a fourth arriving with a
different signature is the case nobody would look for.

## Alternatives rejected

**A gate of its own.** Three symbols and a shared parser. `foreign-width`
already reads every `external` under those two roots, and its multi-line
heading join is the fiddly part; a second gate would have been a copy of it,
free to drift.

**Treat a handle and a `csize` as one class.** It would need no catalogue and
would bless the thing ADR-0128 refuses. The row costs three lines and says
which call and why.

**Compare the corpus too.** `tests/` holds deliberately-wrong bindings —
`foreign_int64_handle.pas` is kept as a gap failing both ways — so a sweep
there would report the tree's own counterexamples as defects. `foreign-width`
scopes to `lib/` and `lsp/` for the same reason.
