# 1. Record architecture decisions

Date: 2026-08-09

## Status

Accepted

## Context

A compiler accumulates decisions whose reasons are invisible in the code that
results from them. The AST avoids `dynamic_cast`, `mod` does not lower to a
plain `srem`, the driver shells out to `clang` instead of linking in process.
Each of those looks like an oversight or an over-complication to a reader — or
to a future contributor — who does not know what it is buying.

The risk is not that someone disagrees. It is that someone "cleans up" a
constraint without noticing it was load-bearing, and the breakage surfaces much
later, in the bootstrap.

## Decision

Keep architecture decision records in `doc/adr/`, numbered and immutable, in
Michael Nygard's format. A record is added when a choice constrains future work,
rules out an obvious alternative, or deviates from what the standard or the
surrounding idiom would suggest.

Routine choices do not get records. Naming, file layout, and anything a reader
can infer from one file stay out.

## Consequences

Decisions become reviewable in isolation and citable from code comments and
commit messages. Superseding a decision means adding a record, so the reasoning
that applied at the time survives even when the conclusion does not.

The cost is discipline: a record written after the fact tends to justify rather
than explain, so they are worth writing while the alternatives are still live.
