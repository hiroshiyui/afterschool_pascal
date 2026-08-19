# 126. The token array was the ceiling

Date: 2026-08-19

## Status

Accepted. A second exception to ADR-0085's refresh-at-release-tags policy, on
the argument ADR-0095 already made and for the array next to the one it moved.

## Context

ADR-0095 raised `poolMax` because the compiler's own source had reached
74 characters under it. Its closing sentence was:

> **It does not change how close to the ceiling the compiler runs.** … Nothing
> measures the headroom; the failure mode is a clear diagnostic at build time,
> which is how this was found.

That is exactly how this was found, four days later. `selfhost/compiler.pas`
tokenises to **139,893 tokens** against `tokMax = 140000` — **107 left, 0.08%
free** — and the first change to add more than that stopped the build with the
compiler's own *"too many tokens: this compiler accepts 140000"*, reported by
the **seed**, which is what translates the source.

The awkwardness is the same one and is worth restating because it is what makes
these two ADRs necessary rather than one-line commits: `seed/pascalc.ll` carries
the *old* bound baked in, so raising the constant in the source does not help
the source. The ceiling moves only by building a compiler with the larger array
and reseeding with it.

Two arrays, two ADRs, four days apart, and neither was predicted. That is the
argument for the third part of this decision.

## Decision

**`tokMax` is 300000 and `poolMax` is 1000000, the seed is refreshed to match,
and the token headroom is now measured on every `ctest` run.**

ADR-0095's reasoning for the out-of-cycle refresh carries over unchanged: a
policy about *noise* should not become a policy about *capability*, and until
the bound changed no further code could be added to the compiler at all.

**Both bounds are sized for roughly twice the present source** rather than for
the next commit. The pool is at 442,625 of 700,000 by a count over the token
stream — 63%, comfortable — but it would have been the next wall at about 1.6×
growth while the tokens were the wall at 1.0×, so raising only the one that
failed would have scheduled the third occurrence. They now run out at about the
same size of source, which is the property worth having: one number to think
about, not two.

**`tests/checks/buffer_headroom.py` is the measurement**, and it is what ADR-0095
said was missing. `--dump-tokens` writes one line per token and a Pascal
string-literal cannot contain a newline (§6.1.7), so the line count *is* the
token count — exact, over a flag that already exists. It fails above 80%, which
is high enough that ordinary growth does not trip it and low enough that the
reseed it asks for is a scheduled decision rather than a wall the next commit
hits. Its message says what to do, because the thing to do is not obvious from
the failure: raise the bound on a tree that still builds, then `seed/refresh.sh`.

**The refresh was done on a tree that builds** — the bounds, the check and
nothing else — so the artefact being trusted is the product of a green tree, as
ADR-0095 required of itself. A fresh configure and build from the new seed
passes all 588 cases.

## Consequences

**Two static arrays grow by 4.8 MB of BSS** — 160,000 more tokens at 28 bytes
and 300,000 more characters at 1 — and nothing at run time. Both are
program-level variables, so they are in the global activation record and not on
any stack.

**A third occurrence is a report rather than a wall**, for the tokens. The gate
names the number every run, so the source can be watched approaching the bound
instead of arriving at it.

### What this does not do

**It does not measure the string pool.** `PoolAdd` is called from Sema and from
CodeGen as well as from the lexer — a type's alias name (§6.4.1's, built for a
diagnostic) and a trap message are both interned — so no count taken over the
token stream is the pool's size, only a lower bound. The 442,625 above is that
lower bound and is quoted as one. `doc/sop.md` §7 carries the gap.

**The exact answer is one flag away and is not taken here.** A `--dump-limits`
writing `poolLen` and `tokCount` after a compilation would close it for both
arrays and for every input rather than for this source, and it is the move if
the pool is ever the ceiling again. It is left undone because a product flag
added to serve a gate wants its own argument, and this change already spends an
out-of-cycle reseed.

**Deduplication is still the answer if the pool bites**, as ADR-0095 said. The
token array has no equivalent — every token is a distinct position — so its only
lever is the bound, which is why the measurement matters more here than there.
