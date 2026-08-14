# 95. The string pool was the ceiling

Date: 2026-08-15

## Status

Accepted. An exception to ADR-0085's refresh-at-release-tags policy, argued
here rather than taken silently.

## Context

`selfhost/compiler.pas` interns every identifier and every literal it reads into
one fixed array, `pool`, bounded by `poolMax = 440000`. **`PoolAdd` does not
deduplicate** — the lexer appends each *occurrence* — so the pool consumed by a
source is roughly the total length of its identifier and literal tokens, and it
grows linearly with the source.

The compiler is a 25,000-line Pascal program that compiles itself, so it is its
own largest input. Adding four diagnostics' worth of message text during a
conformance sweep pushed it **74 characters** over the limit, and the build
failed with the compiler's own *"out of string space"* — reported by the **seed**,
which is what translates the source.

That is the awkward part. `seed/pascalc.ll` carries the *old* `poolMax` baked in,
so raising the constant in the source does not help the source: the seed still
has to hold this source's text. The ceiling could only be raised by building a
compiler with the larger pool and reseeding with it.

## Decision

**`poolMax` is 700000, and the seed is refreshed to match**, out of cycle.

ADR-0085 puts seed refreshes at release tags so that an ordinary compiler change
does not rewrite 6 MB. That reason does not reach this case: what changed is the
seed's **capacity**, and until it changed no further diagnostic could be added
to the compiler at all. A policy about *noise* should not become a policy about
*capability*.

The refresh was done on a tree that builds — `HEAD` plus the one-line bound —
rather than on the change that hit the wall, so the artefact being trusted is
the product of a green tree and nothing else. `seed/refresh.sh` then did what it
always does: built a compiler from the candidate, had that compiler translate
the source again, and required the two results to be identical.

## Consequences

**A fresh configure and build from the new seed passes all 462 cases**, which is
the check that matters: the seed is the only thing standing between this
repository and a working compiler.

**The bound is a static array**, so 260,000 more characters cost 260 KB of BSS
and nothing at run time.

**Deduplication was considered and not done.** It would free far more than
raising the bound — every repeated identifier in a 25,000-line file is stored
again — but `PoolAdd` returns an offset that becomes a symbol's identity, and
making equal spellings share one offset changes what `(at, len)` means
everywhere it is compared. That is a change to the compiler's core data
structure to buy space that a constant buys for free. If the pool is ever the
ceiling again, dedup is the next move, and it deserves its own record.

### What this does not do

**It does not change how close to the ceiling the compiler runs.** The pool is
now about 40% free rather than 0.02% free, which is enough for the sweep that
found the problem and is not a permanent answer. Nothing measures the headroom;
the failure mode is a clear diagnostic at build time, which is how this was
found.
